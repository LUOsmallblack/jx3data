defmodule Jx3App.Application do
  use Application
  require Logger

  def get_args do
    # work around for https://github.com/bitwalker/distillery/issues/611
    args = case System.argv do
      [] -> get_args_from_init()
      args -> args
    end
    args = case args do
      [] -> nil
      [arg, ""] -> String.split(arg) |> Enum.drop(1)
      args -> args
    end
    case args do
      nil -> nil
      ["--" | args] -> args |> Enum.map(&String.to_atom/1)
      args -> args |> Enum.map(&String.to_atom/1)
    end
  end

  def get_args_from_init do
    args = :init.get_plain_arguments |> Enum.map(&List.to_string/1)
    {_, args} = Elixir.Kernel.CLI.parse_argv(args)
    args
  end

  def start(_type, args) do
    args = get_args() || args
    Logger.info("start server with " <> inspect(args))
    case Enum.filter(args, &(&1 not in [:all, :server, :crawler, :cache, :none])) do
      [] -> do_start(args)
      unknown_args ->
        Logger.error("unknown args " <> inspect(unknown_args))
        {:error, "bad args"}
    end
  end

  def do_start(args) do
    import Supervisor.Spec, warn: false

    api_args = Application.get_env(:jx3app, Jx3App.API)
    redix_args = Application.get_env(:jx3app, Jx3App.Cache)[:redis] || []
    server_args = Application.get_env(:jx3app, Jx3App.Server)[:cowboy] || []

    children = [
      # Define workers and child supervisors to be supervised
      # worker(BigLebowski.Worker, [arg1, arg2, arg3])
      worker(Jx3App.Model.Repo, [], restart: :transient),
      worker(Jx3App.Const, [], restart: :transient),
      worker(Jx3App.Task, [], restart: :transient),
      worker(Jx3App.API, [api_args, [name: Jx3App.API]], restart: :transient),
    ] ++
    if Enum.any?([:all, :server, :cache], &(&1 in args)) do [
      :poolboy.child_spec(:redis_pool, [name: {:local, Jx3App.Cache.Redix}, worker_module: Redix, size: 5, max_overflow: 2], redix_args),
      :poolboy.child_spec(:cache_pool, [name: {:local, Jx3App.Cache}, worker_module: Jx3App.Cache, size: 5]),
    ] else [] end ++
    if Enum.any?([:all, :server], &(&1 in args)) do
      [Plug.Cowboy.child_spec(scheme: :http, plug: Jx3App.Server, options: server_args),]
    else [] end ++
    if Enum.any?([:all, :crawler], &(&1 in args)) do
      [worker(Jx3App.Crawler, [], restart: :transient),]
    else [] end

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Jx3App.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
