package jx3app.case_class

import org.apache.spark.sql.Encoders
import org.apache.spark.sql.functions.udf

case class ReplayItem(ts: Long, skillId: Long, casterId: String, targetId: String, skillName: String)
case class RoleItem(team: String, role_id: String, role_name: String, kungfu_name: String, treat_trend: Array[Long], attack_trend: Array[Long], global_role_id: String)
case class Replay(replay: Array[ReplayItem], players: Array[RoleItem], match_id: Long, match_duration: Long)

object Replay {
  val encoder = Encoders.product[Replay]
  val get_first_skill = { replay: Replay => replay.replay(0).skillName }
}
