defmodule Jx3App.Model.Repo.Migrations.CreateRoles do
  use Ecto.Migration

  def change do
    create table(:persons, primary_key: false) do
      add :person_id, :string, primary_key: true
      add :name, :string
      add :avatar, :text
      add :signature, :text
      #add :fetched_at, :naive_datetime_usec
      timestamps(type: :naive_datetime_usec)
    end
    #create index(:persons, :fetched_at)

    create table(:roles, primary_key: false) do
      add :role_id, :id
      add :global_id, :string, primary_key: true
      add :passport_id, :string
      add :name, :string
      add :force, :string
      add :body_type, :string
      add :camp, :string
      add :zone, :string
      add :server, :string
      #add :fetched_at, :naive_datetime_usec
      add :person_id, references(:persons, column: :person_id, type: :string)
      timestamps(type: :naive_datetime_usec)
    end
    create index(:roles, [:role_id, :zone, :server])
    #create index(:roles, :person_id)
    #create index(:roles, :fetched_at)
  end
end
