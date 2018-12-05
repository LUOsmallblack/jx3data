defmodule Jx3App.Server do
  use Plug.Router
  alias Jx3App.GraphQL
  alias Jx3App.Server.{Rest, Website}

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
    pass: ["*/*"],
    json_decoder: Jason

  plug :match
  plug :dispatch

  forward "/api", to: Rest, init_opts: [prefix: "/api"]

  forward "/graphiql", to: Absinthe.Plug.GraphiQL,
    init_opts: [schema: GraphQL.Schema]

  forward "/graphql", to: Absinthe.Plug,
    init_opts: [schema: GraphQL.Schema]

  match _, to: Website

  def not_found(conn) do
    send_resp(conn, 404, "not found" |> Rest.html)
  end
end
