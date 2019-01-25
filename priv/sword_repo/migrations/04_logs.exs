defmodule Jx3App.Sword.SwordRepo.Migrations.CreateLogs do
  use Ecto.Migration

  def change do
    create table(:logs) do
      add :tag, :string
      add :timestamp, :naive_datetime_usec
      add :level, :string
      add :message, :text
      add :metadata, :map
    end
    create index(:logs, [:tag, :level])
    create index(:logs, :timestamp)
  end
end
