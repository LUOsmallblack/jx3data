using Dates

#%%
match_logs = read_df(spark; format="jdbc", options=opts("match_3c.match_logs"))
# match_logs_30days = @spark match_logs.filter(@col inserted_at.gt(@col expr("current_timestamp() + INTERVAL -30 DAYS")))
match_logs_recently = @spark match_logs.filter(@col match_id.gt(int_obj(49600000)))
# @spark match_logs.filter(@col match_id.gt(int_obj(1))).explain()

JReplay_ = @jimport("jx3app.case_class.Replay\$")
JReplay_ = jfield(JReplay_, "MODULE\$", JReplay_)
EncoderReplay = @java JReplay_.encoder()
replay_schema = @java EncoderReplay.schema()
JEncoders = @jimport("org.apache.spark.sql.Encoders")
match_logs_replay_recently = @spark match_logs_recently.select(["replay"]...).as(@java JEncoders.STRING())
match_logs_replay_recently = Dataset(@java spark.jsess.read().schema(@java EncoderReplay.schema()).json(match_logs_replay_recently.jdf))
# @spark match_logs_replay_recently.show()

#%%
match_logs_struct = @spark match_logs_replay_recently.as(EncoderReplay)
@spark match_logs_struct.map(jdcall(JReplay_, "get_first_skill"), @java(JEncoders.STRING())).groupBy(["value"]...).count().sort([@col count.desc()]).show()

#%%
match_logs_recently_tmp = @spark match_logs_replay_recently.join(matches.jdf, seq("match_id"), "left").
    withColumn("team1_size", @col team1_kungfu.size()).
    withColumn("team2_size", @col team1_kungfu.size()).
    filter("size(role_ids) == team1_size+team2_size").
    withColumn("team1_ids", @col expr("slice(role_ids, 1, team1_size)")).
    withColumn("team2_ids", @col expr("slice(role_ids, team1_size+1, team2_size)")).
    withColumn("start_time", @col start_time.from_unixtime().to_timestamp()).
    select(["match_id", "replay", "players", "team1_ids", "team2_ids", "match_duration"]...)

#%%
# udf = @java spark.jsess.udf()
# listmethods(udf, "register")
# listmethods(udf, "registerPython")

#%% analyze whether in team
match_teams = split_team(matches)

in_team_map = @spark(match_teams.
    # select(["match_id", "grade", "kungfus", "start_date", "role_ids"]...).
    withColumn("role_ids", @col role_ids.array_sort()).
    groupBy(["start_date", "role_ids"]...).count().
    withColumn("in_team", @col count.gt(int_obj(3))))

kungfus_weight = @spark(match_teams.
    # --------- kungfu_weight ------------
    join(@spark(in_team_map.selectExpr(["start_date", "role_ids", "in_team"])).jdf, seq("start_date", "role_ids"), "inner").
    select(["start_date", "grade", "kungfus", "in_team", "anta_role_ids", "won"]...).
    join(@spark(in_team_map.selectExpr(["start_date", "role_ids as anta_role_ids", "in_team as anta_in_team"])).jdf, seq("start_date", "anta_role_ids"), "left").
    withColumn("kungfus", @col kungfus.array_sort()).
    withColumn("in_team", @col in_team.when("team").otherwise("person")).
    # withColumn("in_team", @col concat([@col(in_team), @col(lit("_")), @col(anta_in_team)])).
    select(["grade", "kungfus", "in_team", "anta_in_team", "won"]...).
    groupBy(["grade", "kungfus"]...).pivot("in_team", seq("team", "person")).
    agg([
        @col(lit(int_obj(1)).count().alias("count")),
        @col(won.when(int_obj(1)).count().alias("win")),
        @col(anta_in_team.when(int_obj(1)).count().alias("vs_team_count")),
        @col(anta_in_team.and(@col won).when(int_obj(1)).count().alias("vs_team_win")),
    ]...).
    na().fill(0, ["team_count", "person_count"]).
    sort([@col expr("team_count+person_count").desc()]).
    # sort([@col count.desc()]).
    toJSON().take(jint(2000))
    # explain()
    ) |> parse_json

#%%

role_team_weight = @spark(match_teams.
    # select(["match_id", "grade", "kungfus", "start_date", "role_ids"]...).
    withColumn("role_ids", @col role_ids.array_sort()).
    groupBy(["start_date", "role_ids"]...).count().
    withColumn("in_team", @col count.gt(int_obj(3)).when("team").otherwise("person")).
    # --------- role_team_weight ---------
    withColumn("role_ids", @col role_ids.explode()).withColumnRenamed("role_ids", "role_id").
    groupBy(["role_id"]...).pivot("in_team", seq("team", "person")).agg([@col count.sum().alias("count")]...).
    sort([@col expr("team+person").desc()])#.
    # toJSON().take(1000)
    # --------- count_weight ------------
    # groupBy(["count"]...).agg([@col lit(int_obj(1)).count().alias("weight")]...).
    # sort([@col weight.desc()]).toJSON().take(1000)
    # -----------------------------------
    ) #|> parse_json

kungfus_weight[:short] = show_kungfus.(kungfus_weight[:kungfus])
kungfus_weight[:total_count] = kungfus_weight[:person_count] .+ kungfus_weight[:team_count]
kungfus_weight[:team_weight] = kungfus_weight[:team_count] ./ kungfus_weight[:total_count]
kungfus_weight[:person_rate] = kungfus_weight[:person_win] ./ kungfus_weight[:person_count]
kungfus_weight[:team_rate] = kungfus_weight[:team_win] ./ kungfus_weight[:team_count]
kungfus_weight[:cross] = collect(zip(1 .- kungfus_weight[:person_vs_team_count]./kungfus_weight[:person_count], kungfus_weight[:team_vs_team_count]./kungfus_weight[:team_count]))

kungfus_weight_(x; order=:total_count) = sort(kungfus_weight[kungfus_weight[:grade].==x, :], order; rev=true)
kungfus_weight_cols = [:short, :grade, :total_count, :team_weight, :person_rate, :team_rate, :cross]
@show kungfus_weight_(12)[1:200, kungfus_weight_cols]
@show kungfus_weight_(13; order=:team_rate)[1:min(200, end), kungfus_weight_cols]
@show describe(kungfus_weight_(13)[1:min(200, end), kungfus_weight_cols])

@show filter(r->10021 ∈ r[:kungfus], kungfus_weight_(13; order=:team_rate))[kungfus_weight_cols]
# @show filter(r->10021 ∈ r[:kungfus], kungfus_weight_(12; order=:person_count))[[:short, :grade, :person_count, :team_weight, :person_rate, :team_rate, :cross]]
@show filter(r->10014 ∈ r[:kungfus], kungfus_weight_(12; order=:person_count))[[:short, :grade, :person_count, :team_weight, :person_rate, :team_rate, :cross]]
@show kungfu_items

#%%
@df count_weight histogram(:count; weights=:weight, bins=30, yscale=:ln)
@show describe(count_weight)

role_team_weight[:total] = role_team_weight[:in_team] .+ role_team_weight[:in_person]
role_team_weight[:team_rate] = role_team_weight[:in_team] ./ role_team_weight[:total]
@df role_team_weight histogram(:team_rate; weights=:total, bins=20)
@show describe(role_team_weight)
# @show [sum(count_weight[x:end,1]) for x in 1:6]
result = @spark result.toJSON().take(1000)
#%%
# parse_json(@spark match_ids.toJSON().take(1000))
using Dates, TimeZones
# ISOUTCDateTimeFormat = dateformat"yyyy-mm-dd\THH:MM:SS.sss\Z"
mi = parse_json(result)
# mi[:start_time] = DateTime.(mi[:start_time], ISOUTCDateTimeFormat)
mi[:start_date] = Date.(mi[:start_date])
mi
