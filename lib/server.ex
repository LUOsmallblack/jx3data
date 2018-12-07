defmodule Jx3App.Server do
  use Plug.Router
  alias Jx3App.GraphQL
  alias Jx3App.Server.{Rest, Website}

  defmodule Static do
    # TODO: workaround before https://github.com/elixir-plug/plug/pull/795 checked in
    use Plug.Builder, init_mode: :runtime
    import Website, only: [not_found: 2]
    plug Plug.Static, builder_opts()
    plug :not_found
  end

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
    pass: ["*/*"],
    json_decoder: Jason

  plug :match
  plug :dispatch

  forward "/api", to: Rest, init_opts: [prefix: "/api"]

  forward "/static", to: Static, init_opts: [at: "/", from: "./assets/build"]

  forward "/graphiql", to: Absinthe.Plug.GraphiQL,
    init_opts: [schema: GraphQL.Schema, json_codec: Jason]

  forward "/graphql", to: Absinthe.Plug,
    init_opts: [schema: GraphQL.Schema, json_codec: Jason]

  match _, to: Website
end
