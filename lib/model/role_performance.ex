defmodule Jx3App.Model.RolePerformance do
  use Ecto.Schema
  import Ecto.Changeset
  alias Jx3App.Model.Role

  @primary_key false
  schema "scores" do
    belongs_to :role, Role, type: :string, references: :global_id, primary_key: true
    field :match_type, :string, primary_key: true
    field :score, :integer
    field :score2, :integer
    field :grade, :integer
    field :ranking, :integer
    field :ranking2, :integer
    field :total_count, :integer
    field :win_count, :integer
    field :mvp_count, :integer
    field :fetched_count, :integer
    field :fetched_to, :integer
    field :fetched_at, :naive_datetime

    timestamps()
  end

  @permitted ~w(score score2 grade ranking ranking2 total_count win_count mvp_count fetched_count fetched_to fetched_at)a

  def fix_ranking(%{ranking: r} = change) do
    ranking = cond do
      is_integer(r) -> r
      String.at(r, -1) == "%" -> r |> String.trim_trailing("%") |> String.to_integer |> Kernel.-
      true -> r |> String.to_integer
    end
    %{change | ranking: ranking}
  end
  def fix_ranking(change), do: change

  def changeset(perf, change \\ :empty) do
    change = change |> fix_ranking
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Enum.into(%{})
    cast(perf, change, @permitted)
  end
end

defmodule Jx3App.Model.RoleKungfu do
  use Ecto.Schema
  import Ecto.Changeset
  alias Jx3App.Model.Role

  @primary_key false
  schema "role_kungfus" do
    belongs_to :role, Role, type: :string, references: :global_id, primary_key: true
    field :match_type, :string, primary_key: true
    field :kungfu, :string, primary_key: true
    field :mvp_count, :integer
    field :total_count, :integer
    field :win_count, :integer
    field :metrics, {:array, :map}
    field :skills, {:array, :map}

    timestamps()
  end

  @permitted ~w(mvp_count total_count win_count metrics skills)a

  def fix_kungfu_id(%{kungfu: k} = change) do
    kungfu_id = cond do
      is_integer(k) -> k
      is_binary(k) ->  Jx3App.Const.find(:kungfu, k)
    end
    Map.put(change, :kungfu_id, kungfu_id)
  end
  def fix_kungfu_id(change), do: change

  def changeset(perf, change \\ :empty) do
    change = change
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Enum.into(%{})
    cast(perf, change, @permitted)
  end
end

defmodule Jx3App.Model.RolePerformanceLog do
  use Ecto.Schema
  import Ecto.Changeset
  alias Jx3App.Model.{Role, RolePerformance}

  schema "score_logs" do
    field :match_type, :string
    field :score, :integer
    field :grade, :integer
    field :ranking, :integer
    field :total_count, :integer
    field :win_count, :integer
    field :mvp_count, :integer
    belongs_to :role, Role, type: :string, references: :global_id

    timestamps(updated_at: false)
  end

  @permitted ~w(match_type score grade ranking total_count win_count mvp_count role_id)a

  def changeset(perf, change \\ :empty) do
    change = change |> RolePerformance.fix_ranking
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Enum.into(%{})
    cast(perf, change, @permitted)
  end
end
