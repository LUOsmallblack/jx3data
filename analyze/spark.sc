//spark-shell --packages org.postgresql:postgresql:42.2.5
// %%
import $ivy.{
    //`org.apache.hadoop:hadoop-client:3.1.1`,
    `org.apache.spark::spark-sql:2.4.0`,
    `sh.almond::ammonite-spark:0.1.2`,
    `org.postgresql:postgresql:42.2.5`
}

import $cp.jars.`jx3app-analyze.jar`

// %%

import org.apache.spark.sql._
import jx3app.case_class._

// import java.sql.DriverManager
// import org.apache.spark.sql.SparkSession
// import scala.collection.JavaConverters._

// util.Properties.versionNumberString

val spark = AmmoniteSparkSession.builder.
    master("spark://clouds-sp:7077").appName("jx3analyze").
    config("spark.executor.memory", "12g").getOrCreate()

//val cl = ClassLoader.getSystemClassLoader
//cl.loadClass("java.sql.DriverManager")
//cl.asInstanceOf[java.net.URLClassLoader].getURLs.foreach(println)
val opts = Map(
  "url" -> "jdbc:postgresql://localhost:5733/j3",
  "dbtable" -> "match_3c.match_logs",
  "driver" -> "org.postgresql.Driver"
)
//val cl1 = opts.getClass.getClassLoader
//cl1.asInstanceOf[java.net.URLClassLoader].getURLs.foreach(println)
//cl1.getParent

//DriverManager.getDriver(opts.getOrElse("url", ""))
//DriverManager.getDrivers.asScala.foreach(println)

var df = spark.read.format("jdbc").options(opts).load

//%%
//df.explain
import org.apache.spark.sql.functions._
import spark.implicits._
import org.apache.spark.sql.Encoders

//%%
// import org.apache.spark.sql.catalyst.encoders.OuterScopes
// case class ReplayItem(ts: Long, skillId: Long, casterId: String, targetId: String, skillName: String)
// case class RoleItem(team: String, role_id: String, role_name: String, kungfu_name: String, treat_trend: Array[Long], attack_trend: Array[Long], global_role_id: String)
// case class Replay(replay: Array[ReplayItem], team: Array[RoleItem], match_id: Long, match_duration: Long)
// OuterScopes.addOuterScope(this)
//%%
// df = df.filter($"inserted_at" > expr("current_timestamp() + INTERVAL -30 DAYS"))
df = df.filter($"match_id" > 49600000)
val df1 = spark.read.schema(Encoders.product[Replay].schema).json(df.select("replay").as[String]).as[Replay](Encoders.product[Replay])
df1.map(Replay.get_first_skill).groupBy("value").count().show()

spark.close()
