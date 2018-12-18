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

@info "init sword"
Sword.init()
my_spark = connect_spark("spark://clouds-sp:7077")

#%%
@info "load dbs"
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
import Base.convert
JProperties = JavaCall.@jimport(java.util.Properties)
function convert(::Type{JProperties}, src::Dict{String, String})
    prop = JProperties(())
    for (k, v) in src
        @java prop.setProperty(k, v)
    end
    prop
end
function save_db(sdf, tag; db_url="postgresql://localhost:5733/jx3spark", table="v_documents", mode="append")
    @spark sdf.withColumn("tag", @col lit(convert(JavaCall.JString, tag))).write().
        mode(mode).jdbc("jdbc:$(db_url)", table, Dict(
            "driver" => "org.postgresql.Driver",
            "stringtype" => "unspecified"))
    JavaCall.geterror()
end

#%%
@info "grade count"
my_grade_count = grade_count(my_matches)
# my_grade_count |> spark2df
my_grade_count |> sparkagg |> x->save_db(x, "grade_count"; mode="append")

#%%
for i in 1:13
    @info "match count $i"
    split_team(match_grade(my_matches, i)) |> match_count |>
        sparkagg |> x->save_db(x, "kungfus_$i"; mode="append")
end

#%%
close(my_spark)
