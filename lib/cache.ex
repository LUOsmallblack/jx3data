defmodule Jx3App.Cache do
  use GenServer
  import Ecto.Query
  alias Jx3App.{Model, Utils}
  alias Model.{Repo, Item, Person, Role, RoleLog, RolePerformance, Match, MatchRole}
  require Logger

  def call(req) do
    :poolboy.transaction(Jx3App.Cache, fn pid ->
      GenServer.call(pid, req)
    end)
  end

  defmodule Store do
    def exec(command) do
      :poolboy.transaction(Jx3App.Cache.Redix, fn pid ->
        Redix.command(pid, command)
      end)
    end

    def multi(commands) do
      :poolboy.transaction(Jx3App.Cache.Redix, fn pid ->
        Redix.pipeline(pid, commands)
      end)
    end

    def now, do: NaiveDateTime.to_iso8601(NaiveDateTime.utc_now)

    @expire_time 300

    def partition(l, acc \\ [])
    def partition([], acc), do: Enum.reverse(acc)
    def partition([a, b | t], acc) do
      partition(t, [{a, b} | acc])
    end

    def set(key, type \\ "string", value, expire \\ nil)
    def set(key, "string", value, expire) do
      case expire do
        nil -> [["SET", key, value]]
        x when is_number(x) -> [["SETEX", key, x, value]]
      end
    end
    def set(key, type, value, nil), do: set_(key, type, value)
    def set(key, type, value, expire) when is_number(expire) do
      set_(key, type, value) ++ [["EXPIRE", key, expire]]
    end

    def set_(key, "hash", value) do
      Enum.map(value, fn {k, v} -> ["HSET", key, k, v] end)
    end
    def set_(key, "list", value) do
      Enum.map(value, fn v -> ["RPUSH", key, v] end)
    end
    def set_(key, "set", value) do
      Enum.map(value, fn v -> ["SSET", key, v] end)
    end
    def set_(key, "zset", value) do
      Enum.map(value, fn {z, v} -> ["ZADD", key, z, v] end)
    end

    def get_(key, type \\ "string", opts \\ []) do
      length = (opts[:length] || 0) - 1
      case type do
        "string" -> ["GET", key]
        "hash" -> ["HGETALL", key]
        "list" -> ["LRANGE", key, 0, length]
        "set" -> ["SMEMBERS", key]
        "zset" -> ["ZRANGE", key, 0, length, "WITHSCORES"]
      end
    end

    def convert(type, value) do
      case {type, value} do
        {_, nil} -> :error
        {_, []} -> :error
        {"string", _} -> {:ok, value}
        {"hash", _} -> {:ok, partition(value) |> Enum.into(%{})}
        {"list", _} -> {:ok, value}
        {"set", _} -> {:ok, value}
        {"zset", _} -> {:ok, partition(value) |> Enum.map(fn {v1, v2} -> {String.to_integer(v2), v1} end)}
      end
    end

    def get(key, type \\ "string", opts \\ []) do
      case Store.exec(get_(key, type, opts)) do
        {:ok, value} -> convert(type, value)
        _ -> :error
      end
    end

    def do_cache(name, value, opts \\ []) do
      value_key = opts[:value_key] || "#{name}:value"
      time_key = opts[:time_key] || "#{name}:time"
      is_expire = opts[:hard_expire] || false
      expire_time = opts[:expire_time] || @expire_time
      value_type = opts[:type] || "string"
      fun_set = opts[:set] || &set(&1, value_type, &2, is_expire && expire_time || nil)

      Logger.debug("Cache: save #{value_key}")
      Store.multi(
        [["DEL", value_key]] ++
        fun_set.(value_key, value) ++
        [["SET", time_key, now()]]
      )
    end

    def cache_query(name, fun_query, opts \\ []) do
      value_key = opts[:value_key] || "#{name}:value"
      time_key = opts[:time_key] || "#{name}:time"
      is_expire = opts[:hard_expire] || false
      expire_time = opts[:expire_time] || @expire_time
      value_type = opts[:type] || "string"
      fun_get = opts[:get] || &{:ok, &1}
      fun_set = opts[:set] || &set(&1, value_type, &2, is_expire && expire_time || nil)
      fun_query = fun_query || fn -> :error end
      {:ok, time} = Store.exec(["GET", time_key])
      value =
        with {:ok, time} <- NaiveDateTime.from_iso8601(time || ""),
            true <- expire_time > 0 and Utils.time_in?(time, expire_time),
            {:ok, value} <- get(value_key, value_type, opts[:get_opts] || []),
            {:ok, value} <- fun_get.(value)
        do
          value
        else
          _ -> nil
        end
      with nil <- value,
          {:ok, value} <- fun_query.()
      do
        Logger.debug("Cache: save #{value_key}")
        Store.multi(
          [["DEL", value_key]] ++
          fun_set.(value_key, value) ++
          [["SET", time_key, now()]]
        )
        {:ok, value}
      else
        _ ->
          value != nil && {:ok, value} || :error
      end
    end
  end

  def string_to_integer(s) do
    case Integer.parse(s) do
      {x, ""} -> {:ok, x}
      _ -> :error
    end
  end

  def map_mget(%_{} = m, keys) do
    keys
    |> Enum.map(&{&1, Map.get(m, &1)})
    |> Enum.into(%{})
  end

  def map_mget(%{} = m, keys) do
    keys
    |> Enum.map(&{&1, m[Atom.to_string(&1)]})
    |> Enum.into(%{})
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(_) do
    {:ok, nil}
  end

  @impl true
  def handle_call(req, from, state) do
    try do
      {:reply, handle(elem(req, 0), Tuple.delete_at(req, 0)), state}
    rescue e ->
      Logger.error(
        "Cache: " <> Exception.format(:error, e, __STACKTRACE__) <> "\n" <>
        "Last message: " <> inspect(req) <> "\n" <>
        "State: " <> inspect(state) <> "\n" <>
        Utils.format_client(from)
      )
      {:reply, nil, state}
    end
  end

  def handle(:count, {}), do: count()
  def handle(:role, {role_id}), do: summary_role(role_id)
  def handle(:roles, {}), do: roles(200)
  def handle(:person, {person_id}), do: summary_person(person_id)
  def handle(:search_kungfu, {kungfu}), do: search_kungfu(kungfu)
  def handle(:search_role, {role_name}), do: search_role(role_name)
  def handle(:role_log, {role_id}), do: role_log(role_id)

  def items do
    Logger.info("Cache: save items")
    items = Repo.all(from i in Item)
    items |> Enum.flat_map(fn i ->
      Store.set("item:#{i.tag}", "hash", [{i.id, Jason.encode!(i.content)}])
    end) |> Store.multi
    Store.exec(["SET", "item:time", Store.now])
  end

  def get_item(tag, key) do
    {:ok, time} = Store.exec(["GET", "item:time"])
    if time == nil do
      items()
    end
    {:ok, value} = Store.exec(["HGET", "item:#{tag}", key])
    case Jason.decode(value || "") do
      {:ok, value} -> value
      _ -> value
    end
  end

  def roles(limit \\ 200) do
    query = fn ->
      result = Repo.all(from r in Role,
        left_join: s in RolePerformance,
        on: r.global_id == s.role_id,
        where: s.match_type == "3c",
        order_by: [desc: s.score],
        limit: ^limit,
        select: {r, s}
      )
      |> Enum.map(fn {r, s} ->
        %{
          role_id: r.global_id,
          force: r.force,
          name: r.name,
          score: s.score,
          ranking: s.ranking,
          win_rate: Float.round(s.win_count/s.total_count, 3),
        } |> Jason.encode!
      end) |> Enum.with_index(1)
      |> Enum.map(fn {v1, v2} -> {v2, v1} end)
      {:ok, result}
    end
    fun_get = fn v ->
      case {List.first(v), length(v)} do
        {nil, _} -> :error
        {valid, ^limit} when valid >= limit -> {:ok, v}
        _ -> :error
      end
    end
    case Store.cache_query("roles", query, hard_expire: true, expire_time: 3600, type: "zset", get: fun_get, get_opts: [length: limit]) do
      {:ok, result} ->
        result |> Enum.map(fn {_, i} ->
          case Jason.decode(i || "") do
            {:ok, i} -> map_mget(i, ~w(role_id force name score ranking win_rate)a)
            _ -> nil
          end
        end)
      _ -> nil
    end
  end

  def role_log(role_id) do
    keys = ~w(global_id role_id name zone server)a
    query = fn ->
      result = Repo.all(
        from r in RoleLog,
          where: r.global_id == ^role_id,
          order_by: r.seen,
          select: ^keys
      ) |> Enum.map(fn r -> map_mget(r, keys) |> Jason.encode! end)
      {:ok, result}
    end
    case Store.cache_query("role_log:#{role_id}", query, hard_expire: true, expire_time: 36000, type: "list") do
      {:ok, result} ->
        Enum.map(result, fn s ->
          Utils.unwrap(Jason.decode(s || ""))
        end)
      _ -> nil
    end
  end

  def search_role(role_name) do
    roles = Repo.all(
      from r in Role,
      preload: [:person, :performances],
      where: like(r.name, ^"%#{role_name}%"))
    |> Enum.map(&get_summary/1)
    roles |> Enum.map(fn r ->
      Store.do_cache("role:#{r[:role_id]}", r, hard_expire: true, type: "hash")
    end)
    roles |> Enum.map(fn r ->
      ~w(role_id force name zone server person_name)a
      |> Enum.map(&{&1, r[&1]}) |> Enum.into(%{})
    end)
  end

  def get_kungfu(role_id) do
    query = fn ->
      kungfu = Repo.all(
        from r in Role,
        left_join: t in ^MatchRole.subquery("3c"),
        on: r.global_id == t.role_id,
        left_join: m in ^Match.subquery("3c"),
        on: t.match_id == m.match_id,
        where: r.global_id == ^role_id,
        order_by: [desc: m.start_time],
        limit: 100,
        select: t.kungfu
      ) |> Utils.count_word |> Enum.map(fn {k, v} -> {v, get_item(:kungfu, k)} end)
      |> Enum.sort
      {:ok, kungfu}
    end
    Store.cache_query("kungfu:#{role_id}", query, hard_expire: true, expire_time: 3600, type: "zset")
    |> Utils.unwrap
  end

  def search_kungfu(kungfu, opts \\ []) do
    roles(opts[:search] || 3000) |> Enum.filter(fn r ->
      kungfu == case get_kungfu(r[:role_id]) do
        [{_, kungfu} | _] -> kungfu
        _ -> "unknown"
      end
    end) |> Enum.take(opts[:limit] || 100)
  end

  def get_summary(%Model.Role{} = r) do
    person_name = case r.person do
      %Model.Person{} = p -> p.name
      _ -> nil
    end
    %{
      role_id: r.global_id,
      person_id: r.person_id,
      name: r.name,
      zone: r.zone,
      server: r.server,
      force: r.force,
      body_type: r.body_type,
      person_name: person_name,
      fetched_count: r.performances |> Enum.map(fn s -> s.fetched_count end) |> Enum.filter(&!is_nil(&1)) |> Enum.sum(),
      fetched_at: r.performances |> Enum.map(fn s -> s.fetched_at end) |> Enum.filter(&!is_nil(&1)) |> Enum.max(fn->nil end) |> fn x->x && NaiveDateTime.to_string(x) end.(),
      scores: r.performances |> Enum.map(fn s ->
        [s.match_type, s.score, s.ranking, s.total_count, Float.round(s.win_count/s.total_count, 3)] end)
      |> Enum.sort |> Jason.encode!,
    }
  end

  def get_summary(%Model.Person{} = p) do
    %{
      person_id: p.person_id,
      person_name: p.name,
      roles: p.roles |> Enum.map(fn r ->
        [r.global_id, r.name, r.force, r.passport_id] end)
      |> Enum.sort |> Jason.encode!,
    }
  end

  def summary_role(role_id) do
    query = fn ->
      r = Repo.get(from(r in Role, preload: [:person, :performances]), role_id)
      if r do
        {:ok, get_summary(r)}
      else
        :error
      end
    end
    fun_get = fn v ->
      {:ok, map_mget(v, ~w(role_id person_id name zone server force body_type person_name scores fetched_count fetched_at)a)}
    end
    case Store.cache_query("role:#{role_id}", query, hard_expire: true, get: fun_get, type: "hash") do
      {:ok, %{} = result} ->
        result
        |> Map.put(:scores, Utils.unwrap(Jason.decode(result[:scores] || "")))
        |> Map.put(:fetched_at, Utils.unwrap(NaiveDateTime.from_iso8601(result[:fetched_at] || "")))
        |> Map.put(:fetched_count, Utils.unwrap(Ecto.Type.cast(:integer, result[:fetched_count] || "")))
      _ -> nil
    end
  end

  def summary_person(person_id) do
    query = fn ->
      p = Repo.get(from(p in Person, preload: [:roles]), person_id)
      if p do
        {:ok, get_summary(p)}
      else
        :error
      end
    end
    fun_get = fn v ->
      {:ok, map_mget(v, ~w(person_id person_name roles)a)}
    end
    case Store.cache_query("person:#{person_id}", query, hard_expire: true, get: fun_get, type: "hash") do
      {:ok, %{} = result} ->
        result
        |> Map.put(:roles, Utils.unwrap(Jason.decode(result[:roles] || "")))
      _ -> nil
    end
  end

  def count do
    [roles: 60, persons: 60, matches: 30, fetched: 300]
    |> Enum.map(fn {k, e} -> {k, count(k, expire_time: e)} end)
    |> Enum.into(%{})
  end

  def count(key, opts \\ []) do
    opts = Keyword.put_new(opts, :get, &string_to_integer(&1 || ""))
    key_str = "count:" <> cond do
      is_atom(key) or is_number(key) -> "#{key}"
      is_tuple(key) -> key |> Tuple.to_list |> Enum.map(fn i -> "#{i}" end) |> Enum.join(":")
      is_binary(key) -> key
    end
    case Store.cache_query(key_str, fn -> {:ok, count_query(key)} end, opts)
    do
      {:ok, value} -> value
      _ -> nil
    end
  end

  def count_query(:roles) do
    Repo.aggregate(from(r in Role), :count, :global_id)
  end

  def count_query(:unknown_roles) do
    Repo.aggregate(from(r in Role,
      left_join: s in RolePerformance,
      on: r.global_id == s.role_id,
      where: is_nil(s.role_id)), :count, :global_id)
  end

  def count_query(:persons) do
    Repo.aggregate(from(p in Person), :count, :person_id)
  end

  def count_query(:matches) do
    Repo.aggregate(from(m in Match.subquery("3c")), :count, :match_id)
  end

  def count_query(:fetched) do
    Repo.aggregate(from(r in RolePerformance, where: not is_nil(r.fetched_at)), :count, :role_id)
  end

  def count_query({:role_matches, role_id}) do
    Repo.aggregate(from(r in MatchRole.subquery("3c"), where: r.role_id == ^role_id), :count, :match_id)
  end

  def show_all do
    foreach = fn keys, fun ->
      {:ok, result} = keys
        |> Enum.map(fun)
        |> Store.multi
      result
    end
    {:ok, keys} = Store.exec(["KEYS", "*"])
    types = keys |> foreach.(&["TYPE", &1])
    values = Enum.zip(keys, types) |> foreach.(fn {k, t} ->
      Store.get_(k, t)
    end) |> Enum.zip(types) |> Enum.map(fn {v, t} ->
      {:ok, v} = Store.convert(t, v); v
    end)
    ttl = keys |> foreach.(&["TTL", &1])
    Enum.zip(keys, Enum.zip(Enum.zip(types, ttl), values)) |> Enum.into(%{})
  end
end
