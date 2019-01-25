defmodule Jx3App.Model.Repo.Migrations.CreateTempRoles do
  use Ecto.Migration

  def change do
    create table(:lamb_roles, primary_key: false) do
      add :role_id, :id
      add :global_id, :string, primary_key: true
      add :passport_id, :string
      add :name, :string
      add :force, :string
      add :body_type, :string
      add :level, :integer
      add :zone, :string
      add :server, :string
      add :person_id, references(:persons, column: :person_id, type: :string)
      timestamps(type: :naive_datetime_usec)
    end
    create index(:lamb_roles, [:role_id, :zone, :server])
    create index(:lamb_roles, :person_id)
  end
end
