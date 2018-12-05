defmodule Jx3App.Server.Website do
  use Plug.Router
  alias Jx3App.Server.Utils

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
    pass: ["*/*"],
    json_decoder: Jason

  plug :match
  plug :dispatch

  get "/" do
    Utils.redirect(conn, to: "/index.html")
  end

  get "/index.html" do
    send_resp(conn, 200, "welcome to jx3app!")
  end

  match _ do
    not_found(conn)
  end

  def not_found(conn) do
    send_resp(conn, 404, "not found")
  end
end