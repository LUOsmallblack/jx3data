type route = Index | Role(string) | NotFound;
type action =
  | Summary(Api.cache(Summary.summary))
  | Top200(Api.cache(Roles.roles))
  | Route(route);

type state = {
  page: route,
  summary: Api.cache(Summary.summary),
  top200: Api.cache(Roles.roles),
};

let route = url =>
  switch ReasonReact.Router.(url.path) {
  | ["index"] => Index
  | ["role", role_id] => Role(role_id)
  | _ => NotFound
  };

module Component = {
  let getSummary = (_, self) =>
    Api.cacheData(Api.summary, summary => self.ReasonReact.send(Summary(summary)))

  let getTop200 = (_, self) =>
    Api.cacheData(Api.top200, roles => self.ReasonReact.send(Top200(roles)))

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

  let role = (summary, role_id) =>
    <div>
      <div>summary</div>
      <div>
        {ReasonReact.string("role: " ++ role_id)}
      </div>
    </div>;
};

let component = ReasonReact.reducerComponent("RoleKungfu");
let make = (_children) => {
  ...component,
  initialState: () => {
    page: route(ReasonReact.Router.dangerouslyGetInitialUrl()),
    summary: Api.emptyData(),
    top200: Api.emptyData(),
  },
  reducer: (action, state) =>
    switch (action) {
    | Route(route) => ReasonReact.Update({...state, page: route})
    | Summary(summary) => ReasonReact.Update({...state, summary: summary})
    | Top200(roles) => ReasonReact.Update({...state, top200: roles})
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
    | Role(role_id) => Component.role(summary, role_id)
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
