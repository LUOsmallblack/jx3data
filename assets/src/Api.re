
module Axios = {include Axios;};

type cache_status =
  | NotAvailable
  | Loading
  | Fresh(int)
  | Error(string)
  | Expired;

type cache('a) = {
  status: cache_status,
  data: option('a),
};

external asSummary : Js.Json.t => Summary.summary = "%identity";
external asRoles : Js.Json.t => Roles.roles = "%identity";

let summary = () =>
  Js.Promise.(
    Axios.get("/api/summary/count")
    |> then_(resp => resolve(asSummary(resp##data)))
  );

let top200 = () =>
  Js.Promise.(
    Axios.get("/api/roles")
    |> then_(resp => resolve(asRoles(resp##data)))
  );

let getData = ({data}) => data;
let emptyData = () => {status: NotAvailable, data: None};
let cacheData = (~fresh=1800_000, fetch, callback) => {
  callback({status: NotAvailable, data: None});
  Js.Promise.(
    fetch()
    |> then_(data => resolve(callback({status: Fresh(fresh), data: Some(data)})))
    |> catch(error => resolve(callback({status: Error({j|$error|j}), data: None})))
  ) |> ignore
  callback({status: Loading, data: None});
};
