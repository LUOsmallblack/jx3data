defmodule Jx3App.Model.Repo.Migrations.AddPersonFetchedAt do
  use Ecto.Migration

  def change do
    alter table(:persons) do
      add :fetched_at, :naive_datetime_usec
    end
    create index(:persons, :fetched_at)

    alter table(:roles) do
      add :fetched_at, :naive_datetime_usec
    end
    create index(:roles, :fetched_at)
  end
end
