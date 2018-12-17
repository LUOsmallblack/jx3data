defmodule Jx3App.Sword.SwordRepo.Migrations.CreateLoginRole do
  use Ecto.Migration

  def change do
    role = ~s[jx3spark_writer]
    spark_role = ~s["apache-spark"]
    execute ~s|CREATE ROLE #{role}|,
            ~s|DROP ROLE #{role}|
    execute ~s|GRANT ALL PRIVILEGES ON TABLE documents TO #{role}|,
            ~s|REVOKE ALL PRIVILEGES ON TABLE documents FROM #{role}|
    execute ~s|GRANT USAGE, SELECT ON SEQUENCE documents_id_seq TO #{role}|,
            ~s|REVOKE USAGE, SELECT ON SEQUENCE documents_id_seq FROM #{role}|

    execute ~s|GRANT #{role} TO #{spark_role}|,
            ~s|REVOKE #{role} FROM #{spark_role}|
  end
end
