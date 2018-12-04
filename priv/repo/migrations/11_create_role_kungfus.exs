defmodule Model.Repo.Migrations.CreateRoleKungfus do
  use Ecto.Migration

  def change do
    rename table(:scores), :fetch_at, to: :fetched_at
    alter table(:scores) do
      add :fetched_count, :integer
      add :fetched_to, :integer
    end

    create table(:role_kungfus, primary_key: false) do
      add :role_id, :string, primary_key: true
      add :match_type, :string, primary_key: true
      add :kungfu, :string, primary_key: true
      add :mvp_count, :integer
      add :total_count, :integer
      add :win_count, :integer
      add :metrics, {:array, :map}
      add :skills, {:array, :map}

      timestamps(type: :naive_datetime_usec)
    end
  end
end
