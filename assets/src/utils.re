let rec drop(n, list) =
  if (n == 0) { list } else { drop(n-1, switch list {
  | [_, ...t] => t
  | [] => []
  }) };

let take(n, list) = {
  let rec take(n, acc, list) =
    if (n == 0) { List.rev(acc) } else {
      let (acc, t) = switch list {
      | [h, ...t] => ([h, ...acc], t)
      | [] => (acc, [])
      };
      take(n-1, acc, t);
    };
  take(n, [], list)
};

let rec zip(list1, list2) =
  switch (list1, list2) {
  | ([], _) => []
  | (_, []) => []
  | ([x, ...xs], [y, ...ys]) => [(x,y), ...zip(xs, ys)]
  };

module Link = {
  let component = ReasonReact.statelessComponent("Link");
  let handleClick = (href, event) =>
    if (! ReactEvent.Mouse.defaultPrevented(event)) {
      ReactEvent.Mouse.preventDefault(event);
      ReasonReact.Router.push(href)
    };

  let make = (~href, children) => {
    ...component,
    render: (_self) =>
      <a href onClick=handleClick(href)>
        {ReasonReact.array(children)}
      </a>
  }
}
