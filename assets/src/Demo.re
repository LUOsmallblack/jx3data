type element;
[@bs.val] [@bs.return nullable] [@bs.scope "document"] external getElementById : string => option(element) = "getElementById";

[@bs.val] external summary : Summary.summary = "example_data.summary";
[@bs.val] external roles : array(Roles.role) = "example_data.roles";
[@bs.val] external matches : array(Matches.match) = "example_data.matches";

let maybeRenderTo(elementId, reactDom) =
  switch (getElementById(elementId)) {
  | None => ()
  | _ => ReactDOMRe.renderToElementWithId(reactDom, elementId);
  };

maybeRenderTo("summary", <Summary summary />);
maybeRenderTo("top200", <Roles roles />);
maybeRenderTo("matches", <Matches matches />);
