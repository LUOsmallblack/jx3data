[@bs.deriving abstract]
type role = {
  [@bs.as "win_rate"] winRate: float,
  score: int,
  [@bs.as "role_id"] roleId: string,
  name: string,
  force: string,
};
type roles = array(role);

module RoleCard = {
  [@bs.deriving abstract]
  type role_detail = {
    [@bs.as "role_id"] roleId: string,
    name: string,
    [@bs.as "body_type"] bodyType: string,
    force: string,
    server: string,
    zone: string,
    [@bs.as "person_id"] personId: string,
    [@bs.as "person_name"] personName: string,
  };

  type component = ReasonReact.component(ReasonReact.stateless, ReasonReact.noRetainedProps, ReasonReact.actionless);
  let component: component = ReasonReact.statelessComponent("RoleCard");

  let make = (~role: role_detail, _children) => {
    ...component,
    render: _ => {
      <div className="d-inline-flex border border-info">
        <div><span>{ReasonReact.string(role->nameGet)}</span><span>{ReasonReact.string(role->forceGet)}</span></div>
        <div><span>{ReasonReact.string(role->zoneGet)}</span><span>{ReasonReact.string(role->serverGet)}</span></div>
        <div><span>{ReasonReact.string(role->bodyTypeGet)}</span><span>{ReasonReact.string(role->personNameGet)}</span></div>
      </div>
    }
  };
  module Wrapped = {
    type component = ReasonReact.component(ReasonReact.stateless, ReasonReact.noRetainedProps, ReasonReact.actionless);
    type props' = { role: role_detail };
    let make' = (~props: props', children) =>
      make(~role=props.role, children)
  }
};

module RoleCardLink = {
  module TooltipWrapper = Tooltip.Wrapper(RoleCard.Wrapped);
  let component = ReasonReact.statelessComponent("RoleCardLink");
  let make = (~role_id, ~name, ~factory=callback=>callback(None), ~tooltipRef=?, _children) => {
    ...component,
    render: _ => {
      let tooltipRef = switch tooltipRef {
      | None => ref(None)
      | Some(x) => x
      };
      <TooltipWrapper factory tooltipRef>
        <Utils.Link href=("/role/"++role_id)>{ReasonReact.string(name)}</Utils.Link>
      </TooltipWrapper>
    }
  }
};

module Role = {
  let component = ReasonReact.statelessComponent("Role");

  let make = (~role: role, ~tooltipRef=?, _children) => {
    ...component,
    render: _ => {
      let (role_id, name, force, score, win_rate) = (roleIdGet(role), nameGet(role), forceGet(role), scoreGet(role), winRateGet(role));
      <tr>
        <td><RoleCardLink role_id name ?tooltipRef/></td>
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
