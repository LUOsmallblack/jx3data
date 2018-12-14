#%%
import Pkg
Pkg.activate(".")
# ENV["BUILD_SPARK_VERSION"] = "2.4.0"
# ENV["BUILD_SCALA_VERSION"] = "2.12.7"
# Pkg.add("Revise")
# Pkg.add(Pkg.PackageSpec(name="Spark", rev="master"))
# Pkg.add("JavaCall")

#%%
using Revise
using Sword
import Spark, JavaCall

Sword.init()
my_spark = connect_spark("spark://clouds-sp:7077")

#%%
db_url = "postgresql://localhost:5733/j3"
my_items = load_db(my_spark, db_url, "items")
my_matches = load_db(my_spark, db_url, "match_3c.matches")
my_scores = load_db(my_spark, db_url, "scores")
my_role_kungfus = load_db(my_spark, db_url, "role_kungfus")
my_roles = load_db(my_spark, db_url, "roles")
my_match_roles = load_db(my_spark, db_url, "match_3c.match_roles")
Sword.show_tags(my_items)
init_const(my_spark, my_items)

#%%
using Plots, StatPlots
# import PyCall
# PyCall.PyDict(PyCall.pyimport("matplotlib")["rcParams"])["font.family"] = ["sans-serif"]
# PyCall.PyDict(PyCall.pyimport("matplotlib")["rcParams"])["font.sans-serif"] = ["Source Han Serif CN"]
pyplot(xtickfont=font(8, "Source Han Serif CN"))
# RecipesBase.debug()
my_grade_count = grade_count(my_matches)
StatPlots.@df my_grade_count bar(:grade, :count)

#%%
my_kungfus_13 = split_team(match_grade(my_matches, 13))
my_kungfus_13_count = match_count(my_kungfus_13)

sort(my_kungfus_13_count, :rate)
# @df my_kungfus_13_count bar(:short, :count; orientation=:horizontal)
@df my_kungfus_13_count scatter(:won, :count; scale=:log10)
@show filter(r->10021 ∈ r[:kungfus], sort(my_kungfus_13_count, :rate; rev=true))[[:short, :won, :count, :rate]]
@df sort(my_kungfus_13_count, :rate) scatter(:count, :rate; xscale=:log10)

#%%
close(my_spark)
