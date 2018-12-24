[@bs.deriving abstract]
type role = {
  [@bs.as "win_rate"] winRate: float,
  score: int,
  [@bs.as "role_id"] roleId: string,
  name: string,
  force: string,
};
type roles = array(role);

module Role = {
  let component = ReasonReact.statelessComponent("Role");

  let make = (~role: role, _children) => {
    ...component,
    render: _ => {
      let (role_id, name, force, score, win_rate) = (roleIdGet(role), nameGet(role), forceGet(role), scoreGet(role), winRateGet(role));
      <tr>
        <td className="jx3app_role_id">{ReasonReact.string(role_id)}</td>
        <td className="jx3app_role_name">{ReasonReact.string(name)}</td>
        <td className="jx3app_force">{ReasonReact.string(force)}</td>
        <td>{ReasonReact.string(string_of_int(score))}</td>
        <td>{ReasonReact.string(string_of_float(win_rate))}</td>
      </tr>
    }
  }
};

let component = ReasonReact.statelessComponent("Roles");

let make = (~roles, _children) => {
  ...component,
  render: _ => {
    let th = (s) => <th scope="col">{ReasonReact.string(s)}</th>;
    <table className="table table-sm table-hover">
      <thead>
        <tr>
          {th("Role Id")}
          {th("Name")}
          {th("Force")}
          {th("Score")}
          {th("Win Rate")}
        </tr>
      </thead>
      <tbody>
        {Array.map(role => <Role key={roleIdGet(role)} role />, roles) |> ReasonReact.array}
      </tbody>
    </table>
  }
}
