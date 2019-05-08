defmodule Jx3App.Model do
  require Logger
  alias Jx3App.Model.{Item, Person, Role, LambRole, RoleLog, RolePerformance, RoleKungfu, RolePerformanceLog, Match, MatchRole, MatchLog}

  defmodule Repo do
    use Ecto.Repo,
      otp_app: :jx3app,
      adapter: Ecto.Adapters.Postgres
  end

  defmodule AnyType do
    def type, do: :jsonb
    def load(i), do: {:ok, i}
    def cast(i), do: {:ok, i}
    def dump(i), do: {:ok, i}
  end

  defmodule DateRangeType do
    @behaviour Ecto.Type
    def type, do: :daterange
    def load(%Postgrex.Range{} = range), do: apply_range(range, fn x -> Ecto.Type.load(:date, x) end)
    def load(_), do: :error
    def cast([lower, upper], opts) do
      lower_inclusive = case opts[:upper_inclusive] do
        nil -> true
        x -> x
      end
      upper_inclusive = opts[:upper_inclusive] || false
      cast(%Postgrex.Range{lower: lower, lower_inclusive: lower_inclusive, upper: upper, upper_inclusive: upper_inclusive})
    end
    def cast(%Postgrex.Range{} = range), do: apply_range(range, fn x -> Ecto.Type.cast(:date, x) end)
    def cast([lower, upper]), do: cast([lower, upper], [])
    def cast(_), do: :error
    def dump(%Postgrex.Range{} = range), do: apply_range(range, fn x -> Ecto.Type.dump(:date, x) end)
    def dump(_), do: :error
    def apply_range(%Postgrex.Range{lower: lower, upper: upper} = range, func) do
      func = fn nil -> {:ok, nil}; x -> func.(x) end
      case {func.(lower), func.(upper)} do
        {{:ok, lower}, {:ok, upper}} -> {:ok, %{range | lower: lower, upper: upper}}
        _ -> :error
      end
    end

    def in?(%Postgrex.Range{} = r, %Date{} = i) do
      {:ok, r} = cast(r)
      cond do
        r.lower != nil and Date.compare(i, r.lower) == :lt -> false
        r.lower != nil and r.lower_inclusive == false and Date.compare(i, r.lower) == :eq -> false
        r.upper != nil and r.upper_inclusive != true and Date.compare(i, r.upper) == :eq -> false
        r.upper != nil and Date.compare(i, r.upper) == :eq -> false
        true -> true
      end
    end

    def compare(true, false), do: :gt
    def compare(false, true), do: :lt
    def compare(x, y) when is_boolean(x) and is_boolean(y) and x == y, do: :eq
    def compare(r1, r2) do
      r = [
        Date.compare(r1.lower, r2.lower),
        compare(r2.lower_inclusive, r1.lower_inclusive),
        Date.compare(r1.upper, r2.upper),
        compare(r2.upper_inclusive, r1.upper_inclusive),
      ] |> Enum.filter(&:eq != &1)
      case r do
        [i | _] -> i
        [] -> :eq
      end
    end
  end

  defmodule Query do
    import Ecto.Query

    def update_item(%{tag: tag, id: id} = item) do
      {tag, id} = {"#{tag}", "#{id}"}
      case Repo.get_by(Item, [tag: tag, id: id]) do
        nil -> %Item{tag: tag, id: id}
        item -> item
      end
      |> Item.changeset(item) |> Repo.insert_or_update
    end

    def get_items(tag \\ nil) do
      if tag do
        Repo.all(from i in Item, where: i.tag == ^tag)
      else
        Repo.all(from i in Item)
      end
      |> Enum.group_by(fn i -> i.tag end)
    end

    def update_person(%{person_id: id} = person) do
      p = case Repo.get(Person, id) do
        nil -> %Person{person_id: id}
        person -> person
      end
      p |> Person.changeset(person) |> Repo.insert_or_update
    end

    def update_role(%{global_id: id} = role) do
      r = case Repo.get(Role, id) do
        nil -> %Role{global_id: id}
        role -> role
      end
      r |> Role.changeset(role) |> Repo.insert_or_update
    end

    def update_lamb_role(%{global_id: id} = role) do
      r = case Repo.get(LambRole, id) do
        nil -> %LambRole{global_id: id}
        role -> role
      end
      r |> LambRole.changeset(role) |> Repo.insert_or_update
    end

    def remove_lamb_role(%{global_id: id}) do
      r = Repo.get(LambRole, id)
      if r do
        r |> Repo.delete
      end
    end

    def insert_role_log(%{global_id: _} = role) do
      if Map.get(role, :role_id, "") != "" and Map.get(role, :global_id, "") != "" do
        query = ~w(global_id name zone server)a
        |> Enum.map(&{&1, Map.get(role, &1) || ""})
        |> Keyword.put(:role_id, Map.get(role, :role_id) || 0)

        remove_lamb_role(role)
        case Repo.get_by(RoleLog, query) do
          nil -> %RoleLog{} |> RoleLog.changeset(query)
          role -> role
        end |> RoleLog.changeset(role) |> Repo.insert_or_update
      end
    end

    def get_role(id) do
      Repo.get(Role, id)
    end

    def get_role(match_type, id) do
      role = get_role(id)
      perfs = from(p in RolePerformance,
        where: p.match_type == ^match_type and p.role_id == ^id
      ) |> Repo.all |> Enum.at(0)
      {role, perfs}
    end

    def get_roles(opts \\ [match_type: "3c", offset: 0, limit: 5000]) do
      match_type = opts[:match_type] || "3c"
      limit = opts[:limit] || 5000
      offset = opts[:offset] || 0
      query = from(
        r in Role,
        left_join: s in RolePerformance,
        on: r.global_id == s.role_id,
        where: s.match_type == ^match_type or is_nil(s.match_type),
        order_by: [fragment("? DESC NULLS LAST", s.score)],
        offset: ^offset,
        select: {r, s})
      case limit do
        :all -> query
        -1 -> query
        _ -> query |> limit(^limit)
      end
      Repo.all(query)
    end

    def update_performance(%{role_id: id, match_type: mt} = perf) do
      p = case Repo.get_by(RolePerformance, [role_id: id, match_type: mt]) do
        nil -> %RolePerformance{role_id: id, match_type: mt}
        p -> p
      end
      |> RolePerformance.changeset(perf) |> Repo.insert_or_update

      if Map.has_key?(perf, :score) do
        %RolePerformanceLog{} |> RolePerformanceLog.changeset(perf) |> Repo.insert
      end
      p
    end

    def update_kungfus(%{role_id: id, match_type: mt, kungfu: kungfu} = perf) do
      case Repo.get_by(RoleKungfu, [role_id: id, match_type: mt, kungfu: kungfu]) do
        nil -> %RoleKungfu{role_id: id, match_type: mt, kungfu: kungfu}
        p -> p
      end
      |> RoleKungfu.changeset(perf) |> Repo.insert_or_update
    end

    def insert_match(%{match_type: match_type, match_id: id, roles: roles} = match) do
      case Repo.get(Match, id, prefix: Match.prefix(match_type)) do
        nil ->
          multi = Ecto.Multi.new
          |> Ecto.Multi.insert(:match, %Match{match_id: id} |> Match.changeset(match), prefix: Match.prefix(match_type))
          {:ok, r} = Enum.reduce(roles, multi, fn r, multi ->
            role_id = Map.get(r, :global_id)
            changeset = %MatchRole{match_id: id, role_id: role_id} |> MatchRole.changeset(r)
              |> Ecto.Changeset.prepare_changes(fn c ->
                from(r in RolePerformance, where: r.role_id == ^role_id and r.match_type == ^match_type)
                |> c.repo.update_all(inc: [fetched_count: 1])
                c
              end)
            multi |> Ecto.Multi.insert("role_#{role_id}", changeset, prefix: Match.prefix(match_type))
          end)
          |> Repo.transaction
          {:ok, %{Map.get(r, :match) | roles: Enum.map(roles, fn i ->
            role_id = Map.get(i, :global_id)
            Map.get(r, "role_#{role_id}")
          end)}}
        match -> match
      end
    end

    def get_match(match_type, id) do
      Repo.get(Match, id, prefix: Match.prefix(match_type))
    end

    def get_matches(match_type) do
      Repo.all(from(m in Match, order_by: :match_id), prefix: Match.prefix(match_type))
    end

    def get_matches_by_role(match_type, id) do
      Repo.all(from(r in MatchRole, left_join: m in Match, on: r.match_id == m.match_id, where: r.role_id == ^id, order_by: m.start_time, select: m), prefix: Match.prefix(match_type))
    end

    def insert_match_log(%{"match_type" => type, "match_id" => id} = log) do
      case Repo.get(MatchLog, id, prefix: Match.prefix(type)) do
        nil -> %MatchLog{match_id: id} |> MatchLog.changeset(%{replay: log}) |> Repo.insert_or_update(prefix: Match.prefix(type))
        log -> log
      end
    end
  end
end
