defmodule Model.Repo.Migrations.TransferRolePassportData do
  use Ecto.Migration
  import Ecto.Query
  alias Jx3App.Model
  require Logger

  defmodule RolePassportLog do
    use Ecto.Schema

    schema "role_passport_logs" do
      field :global_id, :string
      field :passport_id, :string
      Ecto.Schema.timestamps(type: :naive_datetime_usec, updated_at: false)
    end
  end

  def up do
    from(r in Model.Role,
      where: not is_nil(r.passport_id),
      select: [:global_id, :passport_id, :updated_at])
    |> Model.Repo.all
    |> Enum.map(fn r ->
      %{global_id: r.global_id, passport_id: r.passport_id, inserted_at: r.updated_at}
    end) |> Enum.chunk_every(1000) |> Enum.map(&Model.Repo.insert_all(RolePassportLog, &1))
  end
  def down do

  end
end
