defmodule Jx3App.Model.SwordRepo do
  use Ecto.Repo,
    otp_app: :jx3app,
    adapter: Ecto.Adapters.Postgres,
    priv: "priv/sword_repo"
end

defmodule Jx3App.Model.SwordData do
  def data, do: %{}
end