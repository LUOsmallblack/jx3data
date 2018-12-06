[@bs.deriving abstract]
type summary = {
  roles: int,
  persons: int,
  matches: int,
  fetched: int,
};

module Badge = {
  let component = ReasonReact.statelessComponent("Badge");

  let width = (left, right) => {
    let (left_len, right_len) = (String.length(left), String.length(right));
    let left_percent = float(left_len) /. float(left_len + right_len);
    let len = switch (int_of_float(float(left_len+right_len)*.9.6)) {
    | t when t <= 80 => 80
    | t => t
    };
    (int_of_float(float(len)*.left_percent), len)
  };

  let make = (~left, ~right, ~color="#4c1", _children) => {
    ...component,
    render: _ => {
      let (lw, w) = width(left, right);
      let (lw_5, rw) = (lw+5, w-lw);
      let (lc, rc) = (lw/2, (w+lw)/2);
      <svg className="no-select" height="20" viewBox={j|0 0 $w 20|j} xmlns="http://www.w3.org/2000/svg">
        <linearGradient id="a" x2="0" y2="100%">
          <stop offset="0" stopColor="#bbb" stopOpacity=".1"/>
          <stop offset="2" stopOpacity=".1"/>
        </linearGradient>

        <rect rx="3" width={j|$lw_5|j} height="20" fill="#555"/>
        <rect rx="3" x={j|$lw|j} width={j|$rw|j} height="20" fill=color />

        <path fill=color d={j|M$lw 0h4v20h-4z|j}/>
        <rect rx="3" width={j|$w|j} height="20" fill="url(#a)"/>

        <g fill="#fff" textAnchor="middle" fontFamily="DejaVu Sans,Verdana,Geneva,sans-serif" fontSize="11">
          <text x={j|$lc|j} y="15" fill="#010101" fillOpacity=".3">{ReasonReact.string(left)}</text>
          <text x={j|$lc|j} y="14">{ReasonReact.string(left)}</text>
          <text x={j|$rc|j} y="15" fill="#010101" fillOpacity=".3">{ReasonReact.string(right)}</text>
          <text x={j|$rc|j} y="14">{ReasonReact.string(right)}</text>
        </g>
      </svg>
    }
  }
}

let component = ReasonReact.statelessComponent("Summary");

let simply_string_of_int = (x) => switch x {
| x when x < 1000 => string_of_int(x)
| x when x < 1000*1000 => string_of_float(float(x/100)/.10.) ++ "K"
| x when x < 1000*1000*1000 => string_of_float(float(x/(100*1000))/.10.) ++ "M"
| x => string_of_float(float(x/(100*1000*1000))/.10.) ++ "B"
}

let make = (~summary: summary, _children) => {
  ...component,
  render: _ => {
    let f = (x) => x(summary) |> simply_string_of_int;
    let (roles, persons, matches, fetched) =
      (f(rolesGet), f(personsGet), f(matchesGet), f(fetchedGet));
    <div>
      <span className="mr-1"><Badge left="roles" right={j|$roles|j} /></span>
      <span className="mr-1"><Badge left="persons" right={j|$persons|j} /></span>
      <span className="mr-1"><Badge left="matches" right={j|$matches|j} /></span>
      <span className="mr-1"><Badge left="fetched" right={j|$fetched|j} /></span>
    </div>
  }
}
