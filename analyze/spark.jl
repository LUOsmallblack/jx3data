#%%
using Revise
using Spark
using JavaCall

for x in readdir("jars")
    JavaCall.addClassPath(joinpath("jars", x))
end
Spark.init()
#%%
spark = SparkSession(master="local")
sc = Spark.context(spark)
Spark.add_jar(sc, "jars/postgresql-42.2.5.jar")

#%%
download_jar(coordinate; remoteRepo="https://repo1.maven.org/maven2/") = run(`mvn org.apache.maven.plugins:maven-dependency-plugin:3.1.1:copy -DremoteRepositories=$remoteRepo -Dartifact=$coordinate -DoutputDirectory=jars`)
# download_jar(coordinate) = run(`mvn dependency:get -Dartifact=$coordinate`)
download_jar("org.postgresql:postgresql:42.2.5")

#%%
# nums = parallelize(sc, [1, 2, 3, 0, 4, 0])
# rdd = flat_map(nums, it -> fill(it, it))
# reduce(rdd, +)
opts(table) = Dict(
    "url" => "jdbc:postgresql://localhost:5733/jx3app",
    "dbtable" => table,
    "driver" => "org.postgresql.Driver"
)
read_df(spark; format="jdbc", options=opts("match_3c.matches"))
#%%
close(spark)
