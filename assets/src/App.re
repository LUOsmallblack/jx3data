type route = Index | Role(string) | NotFound;
type action =
  | Summary(Api.cache(Summary.summary))
  | Top200(Api.cache(Roles.roles))
  | Matches(string, Api.cache(Matches.matches))
  | Route(route);

type state = {
  page: route,
  summary: Api.cache(Summary.summary),
  top200: Api.cache(Roles.roles),
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
    Api.cacheData(Api.summary, summary => self.ReasonReact.send(Summary(summary)))

  let getTop200 = ((), self) =>
    Api.cacheData(Api.top200, roles => self.ReasonReact.send(Top200(roles)))

  let getMatches = (role_id, self) =>
    Api.cacheData(Api.matches(role_id), matches => self.ReasonReact.send(Matches(role_id, matches)))

  let index = (summary, roles) => {
    let roles = switch (Api.getData(roles)) {
    | Some(roles) => <Roles roles/>;
    | None => <div>{ReasonReact.string("loading...")}</div>
    };
    <div>
      <div>summary</div>
      <div>roles</div>
    </div>;
  }

  let role = (summary, matches, role_id) => {
    let matches = switch (Utils.find_opt(role_id, matches)) {
    | Some(matches) => Api.getData(matches)
    | None => None
    };
    let matches = switch (matches) {
    | Some(matches) => <Matches matches/>
    | None => <div>{ReasonReact.string("loading...")}</div>
    };
    <div>
      <div>summary</div>
      <div>matches</div>
    </div>
  };
};

let component = ReasonReact.reducerComponent("RoleKungfu");
let make = (_children) => {
  ...component,
  initialState: () => {
    page: route(ReasonReact.Router.dangerouslyGetInitialUrl()),
    summary: Api.emptyData(),
    top200: Api.emptyData(),
    matches: Utils.StringMap.empty,
  },
  reducer: (action, state) =>
    switch (action) {
    | Route(route) =>
        ReasonReact.UpdateWithSideEffects(
          {...state, page: route},
          ({handle}) =>
            switch (route) {
            | Role(role_id) => handle(Component.getMatches, role_id)
            | _ => ()
            }
        )
    | Summary(summary) => ReasonReact.Update({...state, summary: summary})
    | Top200(roles) => ReasonReact.Update({...state, top200: roles})
    | Matches(role_id, matches) => ReasonReact.Update({...state, matches: Utils.StringMap.add(role_id, matches, state.matches)})
    },
  didMount: self => {
    let watcherID = ReasonReact.Router.watchUrl(url => self.send(Route(route(url))));
    self.onUnmount(() => ReasonReact.Router.unwatchUrl(watcherID));
    self.handle(Component.getSummary, ())
    self.handle(Component.getTop200, ())
  },
  render: ({state}) => {
    let summary = switch (Api.getData(state.summary)) {
    | None => <Summary.Badge left="summary" right="calculating..." color="orange" />
    | Some(summary) => <Summary summary />
    }
    switch (state.page) {
    | NotFound => ReasonReact.string("not found")
    | Index => Component.index(summary, state.top200)
    | Role(role_id) => Component.role(summary, state.matches, role_id)
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
