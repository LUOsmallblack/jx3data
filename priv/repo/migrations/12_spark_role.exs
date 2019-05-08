defmodule Jx3App.Model.Repo.Migrations.CreateSparkRole do
  use Ecto.Migration

  def execute_all(up, down) when is_binary(down), do: execute_all(up, String.split(down, ";"))
  def execute_all(up, down) when is_binary(up), do: execute_all(String.split(up, ";"), down)
  def execute_all(up, down) when is_list(up) and is_list(down) do
    len = max(Enum.count(up), Enum.count(down))
    nils = Stream.cycle([nil])
    Stream.zip(Stream.concat(up, nils), Stream.concat(down, nils))
    |> Enum.take(len)
    |> Enum.each(fn {u, d} -> execute(String.trim(u||""), String.trim(d||"")) end)
  end

  def dbname do
    repo().config[:database] || "jx3app"
  end

  def change do
    role = ~s["#{dbname()}_reader"]
    spark_role = ~s["apache-spark"]
    match_schemas = ~w[match_2c match_3c match_5c match_3m]a |> Enum.join(", ")
    create_role role, true
    create_role spark_role, false
    # https://stackoverflow.com/questions/19045149/error-permission-denied-for-schema-user1-gmail-com-at-character-46
    execute_all """
      GRANT SELECT ON ALL TABLES IN SCHEMA public, #{match_schemas} TO #{role};
      ALTER DEFAULT PRIVILEGES IN SCHEMA #{match_schemas} GRANT SELECT ON TABLES TO #{role};
      GRANT USAGE ON SCHEMA public, #{match_schemas} TO #{role};
    """, """
      REVOKE SELECT ON ALL TABLES IN SCHEMA public, #{match_schemas} FROM #{role};
      ALTER DEFAULT PRIVILEGES IN SCHEMA #{match_schemas} REVOKE SELECT ON TABLES FROM #{role};
      REVOKE USAGE ON SCHEMA public, #{match_schemas} FROM #{role};
    """
    execute ~s|GRANT #{role} TO #{spark_role}|,
            ~s|REVOKE #{role} FROM #{spark_role}|
  end

  def create_role(name, force) do
    execute """
    DO language plpgsql $$
    BEGIN
      CREATE ROLE #{name};
    EXCEPTION WHEN others THEN
      RAISE NOTICE '#{name} role exists, not re-creating';
    END
    $$
    """, (if force do "DROP ROLE #{name}" else "" end)
  end
end
