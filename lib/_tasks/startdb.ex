defmodule Mix.Tasks.Jx3app.Startdb do
  use Mix.Task

  @impl true
  def run(args) do
    IO.inspect(args, label: "args")
    tmp_dir = System.tmp_dir! |> Path.join("jx3app")
    File.mkdir_p!(tmp_dir)
    postgresql_port = Application.get_env(:jx3app, Jx3App.Model.Repo)[:port] || 5432
    System.cmd("pg_ctl", ["-Ddata", "-o", "-p#{postgresql_port}", "-lpostgres.log", "start"], cd: "db") |> IO.inspect
    System.cmd("redis-server", ["cache/redis.conf"], cd: "db") |> IO.inspect
  end
end