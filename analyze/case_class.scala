package jx3app.case_class

import org.apache.spark.sql.Encoders

case class ReplayItem(ts: Long, skillId: Long, casterId: String, targetId: String, skillName: String)
case class RoleItem(team: String, role_id: String, role_name: String, kungfu_name: String, treat_trend: Array[Long], attack_trend: Array[Long], global_role_id: String)
case class Replay(replay: Array[ReplayItem], team: Array[RoleItem], match_id: Long, match_duration: Long)

object Replay {
  val encoder = Encoders.product[Replay]
  def get_first_skill(replay: Replay) : String = replay.replay(0).skillName
}
