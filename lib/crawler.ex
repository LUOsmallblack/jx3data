defmodule Jx3App.Crawler do
  alias Jx3App.{Model, API, Utils}
  require Logger

  defmodule Workers do
    use Supervisor

    def start_link(opts) do
      Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def init(opts) do
      children = Enum.map(opts[:match_types], fn t ->
        opts = Keyword.put(opts, :match_type, t)
        worker(Jx3App.Crawler, [opts], restart: :transient, id: t)
      end)
      supervise(children, strategy: :one_for_one)
    end
  end

  def start_link(opts) do
    Logger.info("crawler " <> inspect(opts))
    cond do
      opts[:match_type] -> {:ok, run(opts)}
      opts[:match_types] -> Workers.start_link(opts)
      true -> {:ok, run(opts)}
    end
  end

  def save_performance(_, nil), do: []
  def save_performance(%Model.Role{} = r, perf) do
    perf |> Enum.map(fn i ->
      match_type = i[:match_type]
      with %{} = p <- Map.get(i, :performance),
        p <- p |> Map.put(:match_type, match_type) |> Map.put(:role_id, Map.get(r, :global_id)),
        true <- p[:score] != nil,
        {:ok, p} <- p |> Model.Query.update_performance
      do
        {p, Map.get(i, :metrics)}
      else
        _ -> nil
      end
    end) |> Enum.filter(&(&1!=nil))
  end

  def save_skills(s, m, p) do
    Utils.combine_with(m, s, :kungfu) |> Enum.map(fn {_, v} ->
      case v do
        %{role_id: _} -> Model.Query.update_kungfus(v)
        %{total_count: 0} -> nil
        _ -> %{role_id: Map.get(p, :role_id), match_type: Map.get(p, :match_type)} |> Enum.into(v)
          |> Model.Query.update_kungfus
      end
    end)
  end

  def save_role(a, o \\ nil)
  def save_role(%{person_info: p, role_info: r}, o) do
    person_id = Map.get(p, :person_id)
    if person_id do p |> Model.Query.update_person end
    r = r |> Utils.filter_into(o)
    Map.put(r, :person_id, person_id) |> Model.Query.update_role |> Utils.unwrap
  end
  def save_role(nil, o) do
    o = Utils.unstruct(o)
    Map.put(o, :person_id, nil) |> Model.Query.update_role |> Utils.unwrap
  end

  def save_lamb_role(%{person_info: p, role_info: r}) do
    person_id = Map.get(p, :person_id)
    if person_id do p |> Model.Query.update_person end
    r = r |> Utils.filter_into(%{})
    Map.put(r, :person_id, person_id) |> Model.Query.update_lamb_role |> Utils.unwrap
  end

  def save_match(nil, _), do: nil
  def save_match(detail, m) do
    detail |> Map.get(:roles) |> Enum.map(fn r ->
      # Logger.info("save_match #{inspect(r)}")
      role_seen(r, DateTime.from_unix(detail[:start_time]) |> Utils.unwrap)
    end)
    avg_grade = case Map.get(detail, :grade, nil) do
      nil -> Map.get(m, :avg_grade, nil)
      0 -> Map.get(m, :avg_grade, nil)
      x -> x
    end
    (detail |> Map.put(:grade, avg_grade) |> Model.Query.insert_match |> Utils.unwrap) || detail
  end

  def api(req) do
    GenServer.call(API, req)
  end

  def top200(match_type) do
    top = api({:top200, match_type})
    if top do
      top |> Enum.map(fn %{person_info: _p, role_info: r} = a ->
        save_role(a) |> new_role
        role_seen(r, Date.utc_today)
      end)
    end
  end

  def role_seen(%Model.Role{} = r, seen) do
    r |> Utils.unstruct |> Map.put(:seen, seen) |> Model.Query.insert_role_log
    r
  end
  def role_seen(%{global_id: id} = r, seen) do
    r_now = Model.Query.get_role(id) || new_role(r)
    r |> Utils.filter_into(r_now) |> Map.put(:seen, seen) |> Model.Query.insert_role_log
    r_now
  end

  def new_role(%{global_id: _} = r) do
    r = update_role(r)
    if Map.get(r, :person_id) do
      person(r)
    end
    r
  end

  def update_role(r) do
    result = indicator(role(r))
    result |> Utils.unstruct |> Map.put(:seen, Date.utc_today) |> Model.Query.insert_role_log
    result
  end

  def check_role(%Model.Role{} = r) do
    case Model.Repo.preload(r, [:performances]).performances do
      nil -> update_role(r)
      [] -> update_role(r)
      _ -> r
    end
  end
  def check_role(%{global_id: id} = r) do
    case Model.Query.get_role(id) do
      nil -> update_role(r)
      r -> check_role(r)
    end
  end

  def role(match_type \\ nil, %{global_id: global_id} = r) do
    match_type = case {match_type, Map.get(r, :zone)} do
      {nil, nil} -> "3c"
      {nil, z} -> case Utils.get_zone_suffix(z) do
        "" -> "3c"
        s -> "3" <> s
      end
      {x, _} -> x
    end
    api({:role_info, match_type, global_id}) |> save_role(r)
  end

  def indicator(%{role_id: role_id, zone: zone, server: server} = r) do
    api({:role_info, role_id, zone, server}) |> do_indicator(r)
  end

  def do_indicator(r1, r) do
    result = save_role(r1, r)
    perfs = save_performance(result, r1[:indicator])
    |> Enum.map(fn {p, m} ->
      api({:role_kungfus, Map.get(p, :match_type), Map.get(p, :role_id)}) |> save_skills(m, p)
      p
    end)
    Map.put(result, :performances, perfs)
  end

  def person(%{person_id: person_id}) do
    if person_id != "" and person_id != nil do
      api({:person_roles, person_id}) |> Enum.map(fn r ->
        case r[:role_info][:level] do
          "100" -> save_role(r) |> check_role
          100 -> save_role(r) |> check_role
          _ -> save_lamb_role(r)
        end |> Utils.unstruct |> Map.put(:seen, Date.utc_today) |> Model.Query.insert_role_log
      end)
      Model.Query.update_person(%{person_id: person_id, fetched_at: NaiveDateTime.utc_now})
    end
  end

  @match_default_size 100
  def matches(match_type, %{global_id: global_id}, size \\ @match_default_size) do
    size = size || @match_default_size
    block_size = @match_default_size*2
    block_count = max(div(size-1, block_size)-1, 0)
    history = 0..block_count |> Enum.flat_map(fn i ->
      cur_size = if i == block_count do size - i*block_size else block_size end
      api({:role_history, match_type, global_id, i*block_size, cur_size}) || []
    end)
    history |> Enum.map(fn %{match_id: id, match_type: match_type} = m ->
      Model.Query.get_match(match_type, id) || match(m) || m
    end)
  end

  def match(%{match_id: match_id, match_type: match_type} = m) do
    detail = api({:match_detail, match_type, match_id}) |> save_match(m)
    replay = api({:match_replay, match_type, match_id})
    if replay do replay |> Model.Query.insert_match_log end
    detail
  end

  def do_fetch(role, match_type, perf, opts \\ []) do
    global_id = Map.get(role, :global_id)
    fetched_to = Map.get(perf, :fetched_to) || 0
    # Logger.info("#{inspect(perf)}")
    limit = opts[:limit] || Map.get(perf, :total_count, 1000) - fetched_to

    Logger.info("[#{match_type}] fetching #{limit} matches of #{global_id} of #{Map.get(perf, :score, "??")}")
    history = matches(match_type, role, limit)
    new_perf = %{role_id: global_id, match_type: match_type, fetched_to: fetched_to, fetched_at: NaiveDateTime.utc_now}
    new_perf =
      case history |> Enum.drop_while(fn %Model.Match{} -> false; _ -> true end) do
        [%Model.Match{} = h | _] ->
          roles = Model.Repo.preload(h, :roles).roles
          case roles |> Enum.filter(&(&1 != nil and &1.role_id == role.global_id)) do
            [r] -> new_perf |> Map.put(:score2, r.score2)
            _ ->
              Logger.error("Error when fetching #{global_id}: " <> inspect(roles))
              new_perf
          end
        _ ->
          Logger.info("No match fetched for #{global_id}")
          new_perf
      end
    new_perf = if opts[:limit] == nil do
      fetched_count = history |> Enum.filter(fn %Model.Match{} -> true; _ -> false end) |> Enum.count()
      new_perf |> Map.put(:fetched_count, fetched_count)
    else new_perf end
    Logger.info("[#{match_type}] fetched #{history |> Enum.count} matches of #{global_id} of #{Map.get(perf, :score2, "??")} -> #{new_perf[:score2]}")
    new_perf |> Model.Query.update_performance |> Utils.unwrap
  end

  def fetch(match_type, global_id, opts \\ []) do
    {role, perf} = Model.Query.get_role(match_type, global_id)
    perf = if not Utils.time_in?(role.fetched_at, 24, :hour) do
      indicator(role) |> Map.get(:performances) |> Enum.find(&(Map.get(&1, :match_type) == match_type))
    else
      perf
    end
    last = Map.get(perf, :fetched_at)
    score = Map.get(perf, :score)
    cond do
      score < 2200 and (last == nil or not Utils.time_in?(last, 6, :day)) ->
        do_fetch(role, match_type, perf, Keyword.put(opts, :limit, 100))
      score < 2200 -> nil
      last == nil or not Utils.time_in?(last, 18, :hour) -> do_fetch(role, match_type, perf, opts)
      true -> nil
    end
  end

  def run(opts \\ [mode: :recent]) do
    {match_types, opts} = Keyword.pop(opts, :match_types)
    {match_type, opts} = Keyword.pop(opts, :match_type)
    case {match_type, match_types} do
      {nil, nil} -> do_run("3m", opts)
      {nil, _} -> Enum.map(match_types, fn i -> do_run(i, opts) end)
      _ -> do_run(match_type, opts)
    end
  end

  def do_run(match_type, offset \\ 0, opts) do
    name = opts[:name] || "crawler_#{match_type}"
    limit = 5000
    roles = Model.Query.get_roles(match_type: match_type, offset: offset, limit: limit)
    if not Enum.empty?(roles) do
      Jx3App.Task.start_task(name, roles, fn {r, p} -> fetch(match_type, Map.get(r, :global_id), opts) end, nil, fn -> do_run(match_type, offset+limit, opts) end)
    else
      top200(match_type)
      Jx3App.Task.start_task(name, roles, fn {r, p} -> fetch(match_type, Map.get(r, :global_id), opts) end, nil, fn -> do_run(match_type, 0, opts) end)
    end
  end

  def stop(opts \\ []) do
    match_type = opts[:match_type] || ""
    Jx3App.Task.kill(opts[:name] || "crawler_#{match_type}")
  end
end
