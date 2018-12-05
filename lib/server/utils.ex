defmodule Jx3App.Server.Utils do
  import Plug.Conn

  def send_resp(conn, status, content_type, body) do
    conn
    |> put_resp_header("content-type", content_type)
    |> send_resp(status, body)
  end

  def redirect(conn, opts) when is_list(opts) do
    url  = opts[:to]
    html = Plug.HTML.html_escape(url)
    body = "<html><body>You are being <a href=\"#{html}\">redirected</a>.</body></html>"

    conn
    |> put_resp_header("location", url)
    |> send_resp(conn.status || 302, "text/html", body)
  end
end
