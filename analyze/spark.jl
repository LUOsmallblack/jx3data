#%%
using Revise
using Spark
using JavaCall

include("utils.jl")

for x in readdir("jars")
    JavaCall.addClassPath(joinpath("jars", x))
end
Spark.init()
#%%
spark = SparkSession(master="spark://clouds-sp:7077")
# spark = SparkSession(master="local")
sc = Spark.context(spark)
# Spark.checkpoint_dir!(sc, "/tmp/spark")
Spark.add_jar(sc, "jars/postgresql-42.2.5.jar")

#%%
function init_jar()
    download_jar(coordinate; remoteRepo="https://repo1.maven.org/maven2/") = run(`mvn org.apache.maven.plugins:maven-dependency-plugin:3.1.1:copy -DremoteRepositories=$remoteRepo -Dartifact=$coordinate -DoutputDirectory=jars`)
    # download_jar(coordinate) = run(`mvn dependency:get -Dartifact=$coordinate`)
    download_jar("org.postgresql:postgresql:42.2.5")
end

#%%
# nums = parallelize(sc, [1, 2, 3, 0, 4, 0])
# rdd = flat_map(nums, it -> fill(it, it))
# reduce(rdd, +)
#%%
opts(table) = Dict(
    "url" => "jdbc:postgresql://localhost:5733/j3",
    "dbtable" => table,
    "driver" => "org.postgresql.Driver"
)
items = read_df(spark; format="jdbc", options=opts("items"))
matches = read_df(spark; format="jdbc", options=opts("match_3c.matches"))
scores = read_df(spark; format="jdbc", options=opts("scores"))
role_kungfus = read_df(spark; format="jdbc", options=opts("role_kungfus"))
roles = read_df(spark; format="jdbc", options=opts("roles"))
match_roles = read_df(spark; format="jdbc", options=opts("match_3c.match_roles"))

@spark items.select(["tag"]...).distinct().show()

#%%
include("const.jl")

kungfu_items = @spark items.filter("tag == 'kungfu'").
    select([@col(id.cast("int")), @col(content.trim("\"").alias("content"))]).
    join(df2spark(spark, kungfu_cn_df).jdf, seq("content"), "left_outer")
kungfu_items = @spark(kungfu_items.toJSON().take(200)) |> parse_json
kungfu_items[:content] = Symbol.(kungfu_items[:content])
sort!(kungfu_items, :content; lt=kungfu_isless)
kungfu_items

#%%
using Plots, StatPlots
import PyCall
PyCall.PyDict(PyCall.pyimport("matplotlib")["rcParams"])["font.sans-serif"] = ["Source Han Serif CN"]
pyplot()
# PyCall.PyDict(PyCall.pyimport("matplotlib")["rcParams"])["font.family"] = ["sans-serif"]
# RecipesBase.debug()
grade_count = @spark(matches.groupBy(["grade"]...).count().sort(("count",)...).toJSON().take(200)) |> parse_json
StatPlots.@df grade_count bar(:grade, :count)

#%%
function get_kungfus(matches)
    team1 = @spark matches.selectExpr(["team1_kungfu as kungfu", "winner=1 as won"])
    team2 = @spark matches.selectExpr(["team2_kungfu as kungfu", "winner=2 as won"])
    @spark team1.union(team2.jdf)
end
int_obj(x) = convert(JObject, JInteger((jint,), x))
bool_obj(x) = convert(JObject, JavaObject{Symbol("java.lang.Boolean")}((jboolean,), x))
kungfus_13 = get_kungfus(@spark(matches.filter(@col grade.equalTo(int_obj(13)))))
kungfus_13_count = parse_json(@spark kungfus_13.groupBy(["kungfu"]...).agg([
    @col(lit(int_obj(1)).count().alias("count")),
    @col(won.when(bool_obj(true)).count().alias("won"))]...).sort([@col won.desc()]).toJSON().take(200))

show_kungfus(xs) = join(sort(kungfu_items[[findfirst(x .== kungfu_items[:id]) for x in xs],:], :content; lt=kungfu_isless)[:short])
kungfus_13_count[:short] = show_kungfus.(kungfus_13_count[:kungfu])
kungfus_13_count[:rate] = kungfus_13_count[:won]./kungfus_13_count[:count]
sort(kungfus_13_count, :rate)
# @df kungfus_13_count bar(:short, :count; orientation=:horizontal)
@df kungfus_13_count scatter(:won, :count; scale=:log10)
@df sort(kungfus_13_count, :rate) scatter(:count, :rate; xscale=:log10)
@show filter(r->10021 ∈ r[:kungfu], sort(kungfus_13_count, :rate; rev=true))[[:short, :won, :count, :rate]]

#%%
function kungfu_weight(x)
    role_filtered = @spark scores.filter(@col match_type.equalTo("3c")).filter(@col score.gt(int_obj(x))).join(@spark(role_kungfus.withColumnRenamed("total_count", "kungfu_count")).jdf, seq("role_id", "match_type"))
    kungfu_weight = @spark role_filtered.select(["role_id", "kungfu", "kungfu_count", "total_count"]...).withColumn("kungfu_weight", @col kungfu_count.divide(@col(total_count))).
        groupBy(["kungfu"]...).agg([@col(kungfu_weight.sum().alias("weight")), @col(kungfu_count.sum().alias("count"))]...).sort([@col weight.desc()])
    kungfu_weight = parse_json(@spark(kungfu_weight.toJSON().take(200)))
    kungfu_weight = rename(kungfu_weight, :kungfu => :kungfu_en)
    kungfu_weight[:kungfu_en] = Symbol.(kungfu_weight[:kungfu_en])
    kungfu_weight = join(kungfu_weight, kungfu_items; on=:kungfu_en => :content, kind=:left)
    delete!(kungfu_weight, :short)
    kungfu_weight[:avg_count] = kungfu_weight[:count]./kungfu_weight[:weight]
    kungfu_weight
end
#%%
kungfu_weight_2400 = kungfu_weight(2400)
@show kungfu_weight_2400[[:kungfu, :weight, :count, :avg_count]]
@df kungfu_weight_2400 bar(string.(:kungfu), :weight; ticks=:all)
# @df kungfu_2400_weight bar(string.(:kungfu), :avg_count; ticks=:all)
#%%
macro kungfu_weight(x)
    kw = Symbol("kungfu_weight_$x")
    expr = :($kw = kungfu_weight($x);
        @show $kw[[:kungfu, :weight, :count, :avg_count]];
        @df $kw bar(string.(:kungfu), :weight; ticks=:all);
        # @df $kw bar(string.(:kungfu), :avg_count; ticks=:all))
        )
    @show :($(esc(expr)))
end

@kungfu_weight(2500)
@kungfu_weight(2600)

#%%
close(spark)
