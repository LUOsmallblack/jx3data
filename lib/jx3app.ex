defmodule Jx3App.Application do
  use Application
  require Logger

  def get_args(default) do
    # work around for https://github.com/bitwalker/distillery/issues/611
    args = case System.argv do
      [] -> get_args_from_init()
      args -> args
    end
    case args do
      [] -> default
      [arg, ""] -> String.split(arg) |> Enum.drop(1)
      args -> args
    end
  end

  def get_args_from_init do
    args = :init.get_plain_arguments |> Enum.map(&List.to_string/1)
    {_, args} = Elixir.Kernel.CLI.parse_argv(args)
    args
  end

  @default_config %{roles: [], crawler: [mode: :recent, match_types: ["3c"]]}
  @allowed_roles [:all, :server, :crawler, :cache, :none]
  @allowed_crawler_mode [:all, :setup, :recent]
  def parse_args(args) do
    config = pre_parse_args(args, @default_config)
    case config do
      %{role: []} -> %{config | role: [:none]}
      _ -> config
    end
  end

  def pre_parse_args(["--" | t], config), do: pre_parse_args(t, config)
  def pre_parse_args(t, config), do: parse_args(t, config)
  def parse_args(["--role", roles | t], config) do
    roles = String.split(roles, ",") |> Enum.map(&String.to_atom/1)
    unknown_args = Enum.filter(roles, &(&1 not in @allowed_roles))
    if !Enum.empty?(unknown_args) do
      Logger.error("unknown roles " <> inspect(unknown_args))
    end
    parse_args(t, %{config | roles: roles ++ config[:roles]})
  end
  def parse_args(["--crawler-mode", mode | t], config) do
    mode = String.to_atom(mode)
    if mode not in @allowed_crawler_mode do
      Logger.error("unknown mode " <> inspect(mode))
    end
    parse_args(t, put_in(config, [:crawler, :mode], mode))
  end
  def parse_args(["--crawler-type", match_types | t], config) do
    match_types = if match_types == "none" do
      []
    else
      String.split(match_types, ",")
    end
    parse_args(t, put_in(config, [:crawler, :match_types], match_types))
  end
  def parse_args(["--help" | _], _config) do
    Logger.info("""
      Options:
        --role role1,role2,...: role in #{inspect(@allowed_roles)}, default: :none
        --crawler-mode mode: mode in #{inspect(@allowed_crawler_mode)}, default: :recent
        --crawler-type type1,type2,...: type in [all, none, {2,3,5}{c,d,m}], default: 3c
    """)
    nil
  end
  def parse_args([], config), do: config

  def start(_type, args) do
    args = get_args(args)
    Logger.info("start server with " <> inspect(args))
    case parse_args(args) do
      nil -> :ok
      config -> do_start(config)
    end
  end

  def do_start(config) do
    import Supervisor.Spec, warn: false

    roles = config[:roles]
    crawler_args = config[:crawler]
    api_args = Application.get_env(:jx3app, Jx3App.API)
    redix_args = Application.get_env(:jx3app, Jx3App.Cache)[:redis] || []
    server_args = Application.get_env(:jx3app, Jx3App.Server)[:cowboy] || []
    Keyserver_args

    children = [
      # Define workers and child supervisors to be supervised
      # worker(BigLebowski.Worker, [arg1, arg2, arg3])
      worker(Jx3App.Model.Repo, [], restart: :transient),
      worker(Jx3App.Const, [], restart: :transient),
      worker(Jx3App.Task, [], restart: :transient),
    ] ++
    if Enum.any?([:all, :server, :cache], &(&1 in roles)) do [
      :poolboy.child_spec(:redis_pool, [name: {:local, Jx3App.Cache.Redix}, worker_module: Redix, size: 5, max_overflow: 2], redix_args),
      :poolboy.child_spec(:cache_pool, [name: {:local, Jx3App.Cache}, worker_module: Jx3App.Cache, size: 5]),
    ] else [] end ++
    if Enum.any?([:all, :server], &(&1 in roles)) do
      [Plug.Cowboy.child_spec(scheme: :http, plug: Jx3App.Server, options: server_args),]
    else [] end ++
    if Enum.any?([:all, :crawler], &(&1 in roles)) do [
      worker(Jx3App.API, [api_args, [name: Jx3App.API]], restart: :transient),
      worker(Jx3App.Crawler, [crawler_args], restart: :transient),
    ] else [] end

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Jx3App.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
