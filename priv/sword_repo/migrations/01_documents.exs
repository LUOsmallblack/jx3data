defmodule Jx3App.Model.SwordRepo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:documents) do
      add :tag, :string
      add :content, :map
      add :status, :integer
      timestamps(type: :naive_datetime_usec)
    end
    create index(:documents, [:tag, :status])
    create index(:documents, [:status])
  end
end
