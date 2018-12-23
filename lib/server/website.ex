defmodule Jx3App.Server.Website do
  use Plug.Router
  alias Jx3App.Server.Utils

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
    pass: ["*/*"],
    json_decoder: Jason

  plug :match
  plug :dispatch, builder_opts()

  get "/" do
    Utils.redirect(conn, to: "/index")
  end

  match _ do
    {:ok, content} = File.read("assets/static/index.php.html")
    send_resp(conn, 200, content)
  end

  def not_found(conn, _opts \\ []) do
    send_resp(conn, 404, "not found")
  end
end
