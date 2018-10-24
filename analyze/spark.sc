//spark-shell --packages org.postgresql:postgresql:42.2.5
import java.sql.DriverManager
import org.apache.spark.sql.SparkSession
import scala.collection.JavaConverters._

util.Properties.versionNumberString

//val conf = new SparkConf()
//conf.setMaster("local[*]")
//conf.setAppName("jx3analyze")
//
//val sc = new SparkContext(conf)

val spark = SparkSession.builder.master("local[*]").appName("jx3analyze").getOrCreate()

//val cl = ClassLoader.getSystemClassLoader
//cl.loadClass("java.sql.DriverManager")
//cl.asInstanceOf[java.net.URLClassLoader].getURLs.foreach(println)
val opts = Map(
  "url" -> "jdbc:postgresql://localhost:5733/j3",
  "dbtable" -> "match_3c.matches",
  "driver" -> "org.postgresql.Driver"
)
//val cl1 = opts.getClass.getClassLoader
//cl1.asInstanceOf[java.net.URLClassLoader].getURLs.foreach(println)
//cl1.getParent

//DriverManager.getDriver(opts.getOrElse("url", ""))
//DriverManager.getDrivers.asScala.foreach(println)

val df = spark.read.format("jdbc").options(opts).load

//df.explain
import org.apache.spark.sql.functions._
df.groupBy("grade").count.sort("count").show()
df.groupBy("grade").
  agg(
    count("match_id").alias("count"),
    bround(avg("duration"), 2).alias("duration")).
  sort("grade").show()
