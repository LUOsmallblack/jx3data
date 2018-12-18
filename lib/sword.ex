defmodule Jx3App.Sword.SwordRepo do
  use Ecto.Repo,
    otp_app: :jx3app,
    adapter: Ecto.Adapters.Postgres,
    priv: "priv/sword_repo"
end
