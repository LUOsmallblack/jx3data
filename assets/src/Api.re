
module Axios = {include Axios;};
external asSummary : Js.Json.t => Summary.summary = "%identity";

let summary = () =>
  Js.Promise.(
    Axios.get("/api/summary/count")
    |> then_(resp => resolve(asSummary(resp##data)))
  );
