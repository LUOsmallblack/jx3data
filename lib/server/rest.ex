defmodule Jx3App.Server.Rest do
  use Plug.Router
  alias Jx3App.Cache

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
    pass: ["*/*"],
    json_decoder: Jason

  plug :match
  plug :dispatch, builder_opts()

  @impl true
  def init(opts \\ [prefix: "/api"]) do
    %{
      prefix: opts[:prefix] || "/api"
    }
  end

  @doc "TODO: work around before https://github.com/elixir-plug/plug/pull/794 checked in"
  def opts, do: init()

  def html(str, opts \\ %{}) do
    prefix = opts[:prefix]
    nav = [roles: "#{prefix}/roles", summary: "#{prefix}/summary/count"]
      |> Enum.map(fn {k, v} -> "<span><a href=#{v}>#{k}</a></span>" end)
      |> Enum.join(" ")
    """
    <body>
      <div>
        #{nav}
      </div>
      <pre>#{str}</pre>
    </body>
    """
  end
  def format_replace(str, regex, fun) do
    Regex.replace(regex, str, fn _, pre, mid, suf -> pre <> fun.(mid) <> suf end)
  end

  def format_html(str, opts \\ %{}) do
    str |> format_role_id(opts) |> format_person_id(opts) |> format_name(opts) |> html(opts)
  end

  def format_role_id(str, opts \\ %{}) do
    prefix = opts[:prefix]
    str
    |> format_replace(~r/("role_id":\s*")([^"]+)(",?)/, &~s|<a href="#{prefix}/role/#{&1}">#{&1}</a>|)
    |> format_replace(~r/("global_id":\s*")([^"]+)(",?)/, &~s|<a href="#{prefix}/role/#{&1}">#{&1}</a>|)
    |> format_replace(~r/(")<role_id>:([^"]+)(",?)/, &~s|<a href="#{prefix}/role/#{&1}">#{&1}</a>|)
  end
  def format_person_id(str, opts \\ %{}) do
    prefix = opts[:prefix]
    format_replace(str, ~r/("person_id":\s*")([^"]+)(",?)/, &~s|<a href="#{prefix}/person/#{&1}">#{&1}</a>|)
  end
  def format_name(str, opts \\ %{}) do
    prefix = opts[:prefix]
    Regex.replace(~r/(")<role_id_log:(?<id>[^>]+)>:([^"]+)(",?)/, str, ~s|\\1<a href="#{prefix}/role/log/\\2">\\3</a>\\4|)
  end

  get "/summary/count" do
    send_resp(conn, 200, Jason.encode!(
      Cache.call({:count}), pretty: true) # |> format_html(opts)
    )
  end

  get "/roles" do
    roles = Cache.call({:roles})
    resp = Jason.encode!(roles, pretty: true)
      # |> format_html(opts)
    send_resp(conn, 200, resp)
  end

  get "/role/log/:role_id" do
    role = Cache.call({:role_log, role_id})
    resp = Jason.encode!(role, pretty: true) # |> format_html(opts)
    send_resp(conn, 200, resp)
  end

  get "/role/:role_id" do
    role = Cache.call({:role, role_id})
    case role do
      nil -> not_found(conn)
      _ ->
        role = role |> Map.put(:name, "<role_id_log:#{role[:role_id]}>:" <> role[:name])
        resp = Jason.encode!(role, pretty: true)
          # |> format_html(opts)
        send_resp(conn, 200, resp)
    end
  end

  get "/person/:person_id" do
    person = Cache.call({:person, person_id})
    case person do
      nil -> not_found(conn)
      _ ->
        roles = person[:roles] |> Enum.map(fn [id|t] -> ["<role_id>:"<>id | t] end)
        resp = Jason.encode!(person |> Map.put(:roles, roles), pretty: true)
          # |> format_html(opts)
        send_resp(conn, 200, resp)
    end
  end

  get "/search/role/:role_name" do
    roles = Cache.call({:search_role, role_name})
    resp = Jason.encode!(roles, pretty: true)
      # |> format_html(opts)
    send_resp(conn, 200, resp)
  end

  get "/search/kungfu/:kungfu" do
    roles = Cache.call({:search_kungfu, kungfu})
    resp = Jason.encode!(roles, pretty: true)
      # |> format_html(opts)
    send_resp(conn, 200, resp)
  end

  match _ do
    not_found(conn, opts)
  end

  def not_found(conn, opts \\ %{}) do
    send_resp(conn, 404, Jason.encode!(%{reason: "not found"}))
  end
end
