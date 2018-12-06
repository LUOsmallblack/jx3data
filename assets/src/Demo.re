[@bs.val] external summary : Summary.summary = "example_data.summary";
[@bs.val] external roles : array(Roles.role) = "example_data.roles";

ReactDOMRe.renderToElementWithId(<Summary summary />, "summary");
ReactDOMRe.renderToElementWithId(<Roles roles />, "top200");
