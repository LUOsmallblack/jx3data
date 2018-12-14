defmodule Jx3App.Sword.SwordRepo do
  use Ecto.Repo,
    otp_app: :jx3app,
    adapter: Ecto.Adapters.Postgres,
    priv: "priv/sword_repo"
end

defmodule Jx3App.Sword.Data do
  alias Jx3App.Sword.SwordRepo, as: Repo
  def data, do: %{}
end