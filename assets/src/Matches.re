[@bs.deriving abstract]
type match = {
  matchId: int,
  duration: int,
  grade: int,
  pvpType: int,
  team1Score: int,
  team2Score: int,
  team1Kungfu: array(int),
  team2Kungfu: array(int),
  roleIds: array(string),
  winner: int,
};
type matches = array(match);

module RoleKungfu = {
  module TooltipWrapper = Tooltip.Wrapper(Roles.RoleCard.Wrapped);
  let component = ReasonReact.statelessComponent("RoleKungfu");
  let make = (~bold=false, ~role_id: string, ~kungfu: int, ~factory=?, ~tooltipRef=?, _children) => {
    ...component,
    render: _ => {
      let role_id_url = "/role/" ++ role_id;
      let class_name = if (bold) {" font-weight-bold"} else {""};
      let factory = switch (factory) {
      | Some(factory) => factory(role_id)
      | None => callback=>callback(None)
      };
      let tooltipRef = switch tooltipRef {
        | None => ref(None)
        | Some(x) => x
        };
      <TooltipWrapper factory tooltipRef>
        <span className=("mr-1"++class_name)>
          <Utils.Link href=role_id_url>{ReasonReact.string(string_of_int(kungfu))}</Utils.Link>
        </span>
      </TooltipWrapper>
    }
  }
};

module Match = {
  let component = ReasonReact.statelessComponent("Match");

  let make = (~match: match, ~role_id as cur_role_id=?, ~role_factory=?, ~tooltipRef=?, _children) => {
    ...component,
    render: _ => {
      let (match_id, duration, grade, pvp_type, team1_score, team2_score, team1_kungfu, team2_kungfu, role_ids, winner) =
        (matchIdGet(match), durationGet(match), gradeGet(match), pvpTypeGet(match),
          team1ScoreGet(match), team2ScoreGet(match), team1KungfuGet(match), team2KungfuGet(match),
          roleIdsGet(match), winnerGet(match));
      let (team1_length, _team2_length) = (Array.length(team1_kungfu), Array.length(team2_kungfu));
      let role_id_list = Array.to_list(role_ids);
      let (team1_role_ids, team2_role_ids) = (Utils.take(team1_length, role_id_list), Utils.drop(team1_length, role_id_list));
      let role_kungfus = (kungfus, role_ids) =>
        List.map(
          ((kungfu, role_id)) => {
            let factory = role_factory;
            let bold = switch (cur_role_id) {
            | Some(cur_role_id) when cur_role_id == role_id => true
            | _ => false
            };
            <RoleKungfu key=role_id bold kungfu role_id ?factory ?tooltipRef />
          },
          Utils.zip(kungfus, role_ids)) |> Array.of_list;
      let team1 = role_kungfus(team1_kungfu |> Array.to_list, team1_role_ids);
      let team2 = role_kungfus(team2_kungfu |> Array.to_list, team2_role_ids);
      <tr>
        <td className="jx3app_match_id">{ReasonReact.string({j|$match_id|j})}</td>
        <td>{ReasonReact.string(string_of_int(grade))}</td>
        <td>{ReasonReact.string(string_of_int(duration))}</td>
        <td className="jx3app_match_type">{ReasonReact.string({j|$pvp_type|j})}</td>
        <td>{ReasonReact.string(string_of_int(team1_score/3))}</td>
        <td className="jx3app_role_ids">{ReasonReact.array(team1)}</td>
        <td>{ReasonReact.string(string_of_int(team2_score/3))}</td>
        <td className="jx3app_role_ids">{ReasonReact.array(team2)}</td>
        <td>{ReasonReact.string(string_of_int(winner))}</td>
      </tr>
    }
  }
};

let component = ReasonReact.statelessComponent("Matches");

let make = (~matches, ~role_id=?, ~role_factory=?, ~tooltipRef=?, _children) => {
  ...component,
  render: _ => {
    let th = (s) => <th scope="col">{ReasonReact.string(s)}</th>;
    <table className="table table-sm table-hover">
      <thead>
        <tr>
          {th("Match Id")}
          {th("Grade")}
          {th("Duration")}
          {th("Type")}
          {th("Score1")}
          {th("Role1")}
          {th("Score2")}
          {th("Role2")}
          {th("Winner")}
        </tr>
      </thead>
      <tbody>
        {Array.map(match => <Match key={string_of_int(matchIdGet(match))} match ?role_id ?role_factory ?tooltipRef />, matches) |> ReasonReact.array}
      </tbody>
    </table>
  }
}
