defmodule Mix.Tasks.Jx3app.Stopdb do
  use Mix.Task

  @impl true
  def run(args) do
    IO.inspect(args, label: "args")
    postgresql_port = Application.get_env(:jx3app, Jx3App.Model.Repo)[:port] || 5432
    redis_port = Application.get_env(:jx3app, Jx3App.Cache)[:redis][:port] || 6379
    System.cmd("pg_ctl", ["-Ddata", "-o", "-p#{postgresql_port}", "-lpostgres.log", "stop"], cd: "db") |> IO.inspect
    System.cmd("redis-cli", ["-p", "#{redis_port}", "shutdown"], cd: "db") |> IO.inspect
  end
end