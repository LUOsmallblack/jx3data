type route = Index | Role(string) | NotFound;
type action =
  | Summary(Summary.summary)
  | Route(route);

type state = {
  page: route,
  summary: option(Summary.summary),
};

let route = url =>
  switch ReasonReact.Router.(url.path) {
  | ["index"] => Index
  | ["role", role_id] => Role(role_id)
  | _ => NotFound
  };

let component = ReasonReact.reducerComponent("RoleKungfu");
let make = (_children) => {
  ...component,
  initialState: () => {page: route(ReasonReact.Router.dangerouslyGetInitialUrl()), summary: None},
  reducer: (action, state) =>
    switch (action) {
    | Route(route) => ReasonReact.Update({...state, page: route})
    | Summary(summary) => ReasonReact.Update({...state, summary: Some(summary)})
    },
  didMount: self => {
    let watcherID = ReasonReact.Router.watchUrl(url => self.send(Route(route(url))));
    self.onUnmount(() => ReasonReact.Router.unwatchUrl(watcherID));
  },
  render: ({state}) => {
    let summary = switch (state.summary) {
    | None => <Summary.Badge left="summary" right="calculating..." color="orange" />
    | Some(summary) => <Summary summary />
    }
    switch (state.page) {
    | NotFound => ReasonReact.string("not found")
    | Index => summary
    | Role(role_id) => ReasonReact.string("role " ++ role_id)
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
