defmodule Jx3App.Sword.Repo do
  use Ecto.Repo,
    otp_app: :jx3app,
    adapter: Ecto.Adapters.Postgres,
    priv: "priv/sword_repo"
end

defmodule Jx3App.Sword.Data do
  def data, do: %{}
end