defmodule Jx3App.Model.Repo.Migrations.CreateSparkRole do
  use Ecto.Migration

  def execute_all(up, down) when is_binary(down), do: execute_all(up, String.split(down, ";"))
  def execute_all(up, down) when is_binary(up), do: execute_all(String.split(up, ";"), down)
  def execute_all(up, down) when is_list(up) and is_list(down) do
    len = max(Enum.count(up), Enum.count(down))
    nils = Stream.cycle([nil])
    Stream.zip(Stream.concat(up, nils), Stream.concat(down, nils))
    |> Enum.take(len)
    |> Enum.each(fn {u, d} -> execute(String.strip(u||""), String.strip(d||"")) end)
  end

  def change do
    role = ~s[jx3app_reader]
    spark_role = ~s["apache-spark"]
    match_schemas = ~w[match_2c match_3c match_5c match_2d match_3d match_5d match_2m match_3m match_5m]a |> Enum.join(", ")
    # https://stackoverflow.com/questions/19045149/error-permission-denied-for-schema-user1-gmail-com-at-character-46
    execute_all """
      CREATE ROLE #{role};
      GRANT SELECT ON ALL TABLES IN SCHEMA public, #{match_schemas} TO #{role};
      ALTER DEFAULT PRIVILEGES IN SCHEMA #{match_schemas} GRANT SELECT ON TABLES TO #{role};
      GRANT USAGE ON SCHEMA public, #{match_schemas} TO #{role};
    """, """
      DROP ROLE #{role};
      REVOKE SELECT ON ALL TABLES IN SCHEMA public, #{match_schemas} FROM #{role};
      ALTER DEFAULT PRIVILEGES IN SCHEMA #{match_schemas} REVOKE SELECT ON TABLES FROM #{role};
      REVOKE USAGE ON SCHEMA public, #{match_schemas} FROM #{role};
    """
    execute ~s|GRANT #{role} TO #{spark_role}|,
            ~s|REVOKE #{role} FROM #{spark_role}|
  end
end
