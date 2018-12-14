using Spark

export connect_spark, load_db, init_kungfu_items, split_team, grade_count, match_grade, match_count, kungfu_weight

try_wrap(x::Spark.JDataset) = Dataset(x)

function download_jars()
    download_jar(coordinate; remoteRepo="https://repo1.maven.org/maven2/") = run(`mvn org.apache.maven.plugins:maven-dependency-plugin:3.1.1:copy -DremoteRepositories=$remoteRepo -Dartifact=$coordinate -DoutputDirectory=jars`)
    # download_jar(coordinate) = run(`mvn dependency:get -Dartifact=$coordinate`)
    download_jar("org.postgresql:postgresql:42.2.5")
end

function init()
    # for x in readdir("jars"); JavaCall.addClassPath(joinpath("jars", x)) end
    JavaCall.addClassPath("jars/specialclassloader.jar")
    # JavaCall.addOpts("-Xss8m")
    Spark.init()
    init_java_classloader()
    @java spcl.add("jars/postgresql-42.2.5.jar")
end

connect_spark(master::AbstractString) = connect_spark(
    master,
    Dict(
        "spark.executor.memory"=>"12g",
        # "spark.driver.extraJavaOptions"=>"-Xss16m",
        "spark.sql.session.timeZone"=>"UTC",))
function connect_spark(master, conf)
    spark = SparkSession(master=master; config=conf)
    # spark = SparkSession(master="local")
    sc = Spark.context(spark)
    # @show Spark.set_log_level(sc, "WARN")
    @java sc.jsc.setLogLevel("WARN")
    # Spark.checkpoint_dir!(sc, "/tmp/spark")
    Spark.add_jar(sc, "jars/postgresql-42.2.5.jar")
    return spark
end

jdbc_opts(url, table) = Dict(
    "url" => "jdbc:$(url)",
    "dbtable" => table,
    "driver" => "org.postgresql.Driver")
load_db(spark, url, table) = read_df(spark; format="jdbc", options=jdbc_opts(url, table))

function load_dbs(spark, url)
    global items = load_db(spark, url, "items")
    global matches = load_db(spark, url, "match_3c.matches")
    global scores = load_db(spark, url, "scores")
    global role_kungfus = load_db(spark, url, "role_kungfus")
    global roles = load_db(spark, url, "roles")
    global match_roles = load_db(spark, url, "match_3c.match_roles")
end

#%%
# jdcall_cache_clear!()
show_tags(items) = @spark items.select(["tag"]...).distinct().show()

#%%

function init_kungfu_items(spark, items)
    kungfu_items = @spark items.filter("tag == 'kungfu'").
        select([@col(id.cast("int")), @col(content.trim("\"").alias("content"))]).
        join(df2spark(spark, kungfu_cn_df).jdf, seq("content"), "left_outer")
    kungfu_items = @spark(kungfu_items.toJSON().take(jint(200))) |> parse_json
    kungfu_items[:content] = Symbol.(kungfu_items[:content])
    sort!(kungfu_items, :content; lt=kungfu_isless)
    kungfu_items
end

#%%
grade_count(matches) = @spark(matches.groupBy(["grade"]...).count().sort(("count",)...).toJSON().take(jint(200))) |> parse_json

#%%
function split_team(matches)
    matches = @spark matches.
        withColumn("team1_size", @col team1_kungfu.size()).
        withColumn("team2_size", @col team1_kungfu.size()).
        filter("size(role_ids) == team1_size+team2_size").
        withColumn("team1_ids", @col expr("slice(role_ids, 1, team1_size)")).
        withColumn("team2_ids", @col expr("slice(role_ids, team1_size+1, team2_size)")).
        withColumn("start_time", @col start_time.from_unixtime().to_timestamp())
    basic_cols = ["match_id", "grade", "start_time", "pvp_type"]
    team1 = @spark matches.selectExpr([basic_cols; "team1_kungfu as kungfus"; "team1_ids as role_ids"; "winner=1 as won"; "team2_ids as anta_role_ids"; "team2_kungfu as anta_kungfus"])
    team2 = @spark matches.selectExpr([basic_cols; "team2_kungfu as kungfus"; "team2_ids as role_ids"; "winner=2 as won"; "team1_ids as anta_role_ids"; "team1_kungfu as anta_kungfus"])
    @spark team1.union(team2.jdf).
        withColumn("start_date", @col start_time.to_date())
end
match_grade(matches, x) = @spark(matches.filter(@col grade.equalTo(int_obj(x))))
function match_count(match_teams)
    match_count = parse_json(@spark match_teams.groupBy(["kungfus"]...).
        agg([@col(lit(int_obj(1)).count().alias("count")), @col(won.when(int_obj(1)).count().alias("won"))]...).
        sort([@col won.desc()]).toJSON().take(jint(200)))
    match_count[:short] = show_kungfus.(match_count[:kungfus])
    match_count[:rate] = match_count[:won]./match_count[:count]
    match_count
end

# sort(kungfus_13_count, :rate)
# # @df kungfus_13_count bar(:short, :count; orientation=:horizontal)
# @df kungfus_13_count scatter(:won, :count; scale=:log10)
# @show filter(r->10021 ∈ r[:kungfus], sort(kungfus_13_count, :rate; rev=true))[[:short, :won, :count, :rate]]
# @df sort(kungfus_13_count, :rate) scatter(:count, :rate; xscale=:log10)

#%%
function kungfu_weight(x)
    role_filtered = @spark scores.filter(@col match_type.equalTo("3c")).filter(@col score.gt(int_obj(x))).join(@spark(role_kungfus.withColumnRenamed("total_count", "kungfu_count")).jdf, seq("role_id", "match_type"))
    kungfu_weight = @spark role_filtered.select(["role_id", "kungfu", "kungfu_count", "total_count"]...).withColumn("kungfu_weight", @col kungfu_count.divide(@col(total_count))).
        groupBy(["kungfu"]...).agg([@col(kungfu_weight.sum().alias("weight")), @col(kungfu_count.sum().alias("count"))]...).sort([@col weight.desc()])
    kungfu_weight = parse_json(@spark(kungfu_weight.toJSON().take(jint(200))))
    kungfu_weight = rename(kungfu_weight, :kungfu => :kungfu_en)
    kungfu_weight[:kungfu_en] = Symbol.(kungfu_weight[:kungfu_en])
    kungfu_weight = join(kungfu_weight, kungfu_items; on=:kungfu_en => :content, kind=:left)
    delete!(kungfu_weight, :short)
    kungfu_weight[:avg_count] = kungfu_weight[:count]./kungfu_weight[:weight]
    kungfu_weight
end
# kungfu_weight_2400 = kungfu_weight(2400)
# @show kungfu_weight_2400[[:kungfu, :weight, :count, :avg_count]]
# @df kungfu_weight_2400 bar(string.(:kungfu), :weight; ticks=:all)
# @df kungfu_2400_weight bar(string.(:kungfu), :avg_count; ticks=:all)
#%%
macro kungfu_weight(x)
    kw = Symbol("kungfu_weight_$x")
    expr = :($kw = kungfu_weight($x);
        @show $kw[[:kungfu, :weight, :count, :avg_count]];
        @df $kw bar(string.(:kungfu), :weight; ticks=:all);
        # @df $kw bar(string.(:kungfu), :avg_count; ticks=:all))
        )
    :($(esc(expr)))
end

# @kungfu_weight(2500)
# @kungfu_weight(2600)

#%%
# close(spark)
