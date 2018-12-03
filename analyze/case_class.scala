package jx3app.case_class

import org.apache.spark.sql.Encoders
import org.apache.spark.sql.functions.udf

//%%
// getClass.getClassLoader
// java.lang.Thread.currentThread.getContextClassLoader
// val thread = new java.lang.Thread { override def run { println(java.lang.Thread.currentThread.getContextClassLoader) } }
// thread.getClass.getClassLoader
// thread.getClass.getClassLoader.getClass.getClassLoader
// thread.getClass.getClassLoader.getClass.getClassLoader.getClass.getClassLoader
// 1.getClass.getClassLoader
//%%

import java.lang.{Class, ClassLoader, ClassNotFoundException}
object Loader {
  def loadClass[T](name: String, init: Boolean, loader: ClassLoader) : Class[T] = {
    val thread = new Thread {
      override def run {
        Class.forName(name, init, loader)
      }
      setContextClassLoader(loader)
      start; join
    }
    loadClass(name, loader)
  }

  def loadClass[T](name: String, loader: ClassLoader) : Class[T] = {
    Class.forName(name, false, loader) match {
      case clazz: Class[T] => clazz
      case _ => throw new ClassNotFoundException(name)
    }
  }
}

case class ReplayItem(ts: Long, skillId: Long, casterId: String, targetId: String, skillName: String)
case class RoleItem(team: String, role_id: String, role_name: String, kungfu_name: String, treat_trend: Array[Long], attack_trend: Array[Long], global_role_id: String)
case class Replay(replay: Array[ReplayItem], players: Array[RoleItem], match_id: Long, match_duration: Long)

object Replay {
  val encoder = Encoders.product[Replay]
  val get_first_skill = { replay: Replay => replay.replay(0).skillName }
}
