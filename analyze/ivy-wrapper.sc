//!/bin/env scala

val arglist = args.toList
def nextOption(depList : List[(String, String, String)], other : List[String], args : List[String])
  : (List[(String, String, String)], List[String]) = {
  args match {
    case Nil => (depList.reverse, other.reverse)
    case "-dependency" :: orgName :: artifactId :: version :: tail =>
      nextOption((orgName, artifactId, version)::depList, other, tail)
    case o :: tail =>
      nextOption(depList, o::other, tail)
  }
}
val (deps, args_) = nextOption(Nil, Nil, args.toList)
val depsString = deps.map(dep => s"""    <dependency org="${dep._1}" name="${dep._2}" rev="${dep._3}" conf="default->*"/>""").mkString("\n")
val xmlString = s"""<?xml version="1.0" encoding="UTF-8"?>
<ivy-module version="2.0">
  <info organisation="org.apache.ivy" module="ivy-caller" revision="working" status="release" default="true"/>
  <configurations>
    <conf name="default" visibility="public"/>
  </configurations>
  <dependencies>
$depsString
  </dependencies>
</ivy-module>
"""
/*
  <publications>
    <artifact name="ivy-caller" type="jar" ext="jar" conf="default"/>
  </publications>
 */
import java.io._
import scala.sys.process._

val file = new File("ivy.tmp.xml")
val writer = new PrintWriter(file)
writer.write(xmlString)
writer.close()

try {
  val cmd = Seq("ivy", "-ivy", file.getPath()) ++ args_
  println("invoke: " + cmd.map(s => s"'$s'").mkString(" "))
  cmd.lineStream.foreach { println(_) }
} finally {
  file.delete()
}
