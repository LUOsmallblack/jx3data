defmodule Jx3App.Model.Person do
  use Ecto.Schema
  import Ecto.Changeset
  alias Jx3App.Model.Role

  @primary_key {:person_id, :string, autogenerate: false}
  schema "persons" do
    # globalId, passportId, personId
    # personInfo: { bodyType, force, gameGlobalRoleId, gameRoleId, miniAvatar, passportId, person: {avatarUrl, id, nickName, signature}, roleName, server, zone }
    # rankNum, score, upNum, winRate
    field :name, :string
    field :avatar, :string
    field :signature, :string
    field :fetched_at, :naive_datetime_usec
    has_many :roles, Role, foreign_key: :person_id
    timestamps(type: :naive_datetime_usec)

    @permitted ~w(name avatar signature fetched_at)a

    def changeset(person, change \\ :empty) do
      change = change
      |> Enum.filter(fn {_, v} -> v != nil end)
      |> Enum.into(%{})
      cast(person, change, @permitted)
    end
  end
end
