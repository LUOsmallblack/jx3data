defmodule Jx3App.Sword.Model.Log do
  use Ecto.Schema
  import Ecto.Changeset
  alias Jx3App.Model.AnyType

  schema "logs" do
    field :tag, :string
    field :timestamp, :naive_datetime_usec
    field :level, :string
    field :message, :string
    field :metadata, AnyType

    @permitted ~w(tag timestamp level message metadata)a

    def time_from_erl({a, {b,c,d,e}}) do
      NaiveDateTime.from_erl!({a, {b,c,d}}, {e*1000, 3})
    end

    def pre_json(a) when is_list(a) do
      cond do
        Keyword.keyword?(a) -> pre_json(Enum.into(a, %{}))
        true -> Enum.map(a, &pre_json/1)
      end
    end
    def pre_json(a) when is_tuple(a) do
      a |> Tuple.to_list |> pre_json # |> List.to_tuple
    end
    def pre_json(a) when is_map(a) do
      Enum.map(a, fn {k, v} -> {pre_json(k), pre_json(v)} end) |> Enum.into(%{})
    end
    def pre_json(a) when is_binary(a) or is_integer(a) or is_float(a) or is_boolean(a) or is_atom(a), do: a
    def pre_json(a) do
      try do
        "#{a}"
      rescue
        _ -> inspect(a)
      end
    end

    def changeset(log, change \\ :empty) do
      # TODO: cast fields
      change = change
      |> Enum.filter(fn {_, v} -> v != nil end)
      |> Enum.into(%{})
      cast(log, change, @permitted)
    end
  end
end

defmodule Jx3App.Sword.LoggerBackend do
  alias Jx3App.Sword.Model.Log
  @behaviour :gen_event

  def init({__MODULE__, name}) do
    # TODO: default settings
    {:ok, Application.get_env(:logger, name) |> IO.inspect}
  end

  def handle_call({:configure, _options}, state) do
    {:ok, :ok, state}
  end

  def handle_event({level, _group_leader, {Logger, message, timestamp, metadata}}, state) do
    cond do
      Logger.compare_levels(level, state[:level] || :warn) == :lt -> {:ok, state}
      true ->
        log = %Log{}
        |> Log.changeset(%{tag: "elixir", level: Atom.to_string(level), timestamp: Log.time_from_erl(timestamp), message: inspect(message), metadata: Log.pre_json(metadata)})
        try do
          Jx3App.Sword.SwordRepo.insert(log)
        rescue
          _ -> :error
        end
        {:ok, state}
    end
  end
  
  def handle_event(:flush, state) do
    {:ok, state}
  end
end
