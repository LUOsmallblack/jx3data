defmodule Jx3App.Sword.SwordRepo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:documents) do
      add :tag, :string
      add :content, {:array, :map}
      add :status, :integer
      timestamps(type: :naive_datetime_usec)
    end
    create index(:documents, [:tag, :status])
    create index(:documents, [:status])
  end
end
