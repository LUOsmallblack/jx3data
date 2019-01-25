defmodule Jx3App.Sword.SwordRepo.Migrations.CreateLoginRole do
  use Ecto.Migration

  def change do
    role = ~s[jx3spark_writer]
    spark_role = ~s["apache-spark"]
    create_role role, true
    create_role spark_role, false
    execute ~s|GRANT ALL PRIVILEGES ON TABLE documents TO #{role}|,
            ~s|REVOKE ALL PRIVILEGES ON TABLE documents FROM #{role}|
    execute ~s|GRANT USAGE, SELECT ON SEQUENCE documents_id_seq TO #{role}|,
            ~s|REVOKE USAGE, SELECT ON SEQUENCE documents_id_seq FROM #{role}|

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
