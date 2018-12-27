type route = Index | Role(string) | NotFound;
type action =
  | Summary(Api.cache(Summary.summary))
  | Top200(Api.cache(Roles.roles))
  | Role(string, Api.cache(Roles.RoleCard.role_detail))
  | Matches(string, Api.cache(Matches.matches))
  | Route(route);

type state = {
  page: route,
  tooltip: ref(option(ReasonReact.reactRef)),
  summary: Api.cache(Summary.summary),
  top200: Api.cache(Roles.roles),
  roles: Utils.StringMap.t(Api.cache(Roles.RoleCard.role_detail)),
  matches: Utils.StringMap.t(Api.cache(Matches.matches)),
};

let route = url =>
  switch ReasonReact.Router.(url.path) {
  | ["index"] => Index
  | ["role", role_id] => Role(role_id)
  | _ => NotFound
  };

module Component = {
  let getSummary = ((), self) =>
    Api.cacheData(Api.summary, summary => self.ReasonReact.send(Summary(summary)));

  let getTop200 = ((), self) =>
    Api.cacheData(Api.top200, roles => self.ReasonReact.send(Top200(roles)));

  let getRole = (role_id, self) =>
    Api.cacheData(Api.role(role_id), role => self.ReasonReact.send(Role(role_id, role)));

  let getMatches = (role_id, self) =>
    Api.cacheData(Api.matches(role_id), matches => self.ReasonReact.send(Matches(role_id, matches)));

  let fetchRoute = (route, self) =>
    switch (route) {
    | Index => self.ReasonReact.handle(getTop200, ())
    | Role(role_id) =>
      self.ReasonReact.handle(getRole, role_id);
      self.ReasonReact.handle(getMatches, role_id)
    | _ => ()
    };

  let index = (summary, roles) => {
    let roles = switch (Api.getData(roles)) {
    | Some(roles) => <Roles roles/>;
    | None => <div>{ReasonReact.string("loading...")}</div>
    };
    <div>
      <div>summary</div>
      <div>roles</div>
    </div>;
  };

  module Tooltip' = Tooltip.Make(Roles.RoleCard.Wrapped);
  let role = (summary, {tooltip, matches, roles}, handle, role_id) => {
    let setTooltipRef = (theRef, {ReasonReact.state}) => {
      state.tooltip := Js.Nullable.toOption(theRef);
    };
    let matches = switch (Utils.find_opt(role_id, matches)) {
    | Some(matches) => Api.getData(matches)
    | None => None
    };
    let role = switch (Utils.find_opt(role_id, roles)) {
    | Some(role) => Api.getData(role)
    | None => None
    };
    let factory = (role_id, callback) => Api.cacheData(Api.role(role_id), role => callback(
      switch (Api.getData(role)) {
      | Some(role) => Some({Roles.RoleCard.Wrapped.role: role}) | None => None}));
    let matches = switch (matches) {
    | Some(matches) => <Matches matches role_id role_factory=factory tooltipRef=tooltip />
    | None => <div>{ReasonReact.string("loading...")}</div>
    };
    let role = switch (role) {
    | Some(role) => <Roles.RoleCard role/>
    | None => <Roles.RoleCardLink tooltipRef=tooltip factory role_id name="loading..."/>
    };
    <div>
      <div>summary</div>
      <div>role</div>
      <div>matches</div>
      <Tooltip' ref={handle(setTooltipRef)}/>
    </div>
  };
};

let component = ReasonReact.reducerComponent("App");
let make = (_children) => {
  ...component,
  initialState: () => {
    page: route(ReasonReact.Router.dangerouslyGetInitialUrl()),
    tooltip: ref(None),
    summary: Api.emptyData(),
    top200: Api.emptyData(),
    roles: Utils.StringMap.empty,
    matches: Utils.StringMap.empty,
  },
  reducer: (action, state) =>
    switch (action) {
    | Route(route) when route != state.page =>
        ReasonReact.UpdateWithSideEffects(
          {...state, page: route},
          self => Component.fetchRoute(route, self)
        )
    | Route(_) => ReasonReact.NoUpdate
    | Summary(summary) => ReasonReact.Update({...state, summary: summary})
    | Top200(roles) => ReasonReact.Update({...state, top200: roles})
    | Role(role_id, role) => ReasonReact.Update({...state, roles: Utils.StringMap.add(role_id, role, state.roles)})
    | Matches(role_id, matches) => ReasonReact.Update({...state, matches: Utils.StringMap.add(role_id, matches, state.matches)})
    },
  didMount: self => {
    let watcherID = ReasonReact.Router.watchUrl(url => self.send(Route(route(url))));
    self.onUnmount(() => ReasonReact.Router.unwatchUrl(watcherID));
    self.handle(Component.getSummary, ());
    Component.fetchRoute(self.state.page, self)
  },
  render: ({state, handle}) => {
    let summary = switch (Api.getData(state.summary)) {
    | None => <Summary.Badge left="summary" right="calculating..." color="orange" />
    | Some(summary) => <Summary summary />
    }
    switch (state.page) {
    | NotFound => ReasonReact.string("not found")
    | Index => Component.index(summary, state.top200)
    | Role(role_id) => Component.role(summary, state, handle, role_id)
    }
  }
};

type element;
[@bs.val] [@bs.return nullable] [@bs.scope "document"] external getElementById : string => option(element) = "getElementById";
let maybeRenderTo(elementId, reactDom) =
  switch (getElementById(elementId)) {
  | None => ()
  | _ => ReactDOMRe.renderToElementWithId(reactDom, elementId);
  };
maybeRenderTo("container", ReasonReact.element(make([])))
