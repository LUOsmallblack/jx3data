defmodule Jx3App.Model.Dynamic do
  require Ecto.Query
  alias Ecto.Query, as: Sql
  
  def build(expr) do
    binding = find_binding(expr) |> Enum.map(fn x -> {x, [], nil} end)
    build(binding, expr, %{file: "<input>", line: 1})
  end
  def build(binding, expr, env) do
    {_query, vars} = Sql.Builder.escape_binding(quote(do: query), binding, env)
    {expr, {params, :acc}} = Sql.Builder.escape(expr, :any, {[], :acc}, vars, env)
    params = Sql.Builder.escape_params(params)

    %Ecto.Query.DynamicExpr{fun: fn query ->
      _ = query
      {unescape(expr), unescape(params)}
    end,
    binding: binding,
    file: env.file,
    line: env.line}
  end

  # https://github.com/elixir-lang/elixir/blob/master/lib/elixir/src/elixir_quote.erl
  def unescape({:{}, [], x}) when is_list(x), do: unescape(x) |> List.to_tuple
  def unescape({:%{}, [], x}) when is_list(x), do: unescape(x) |> Map.new
  # https://github.com/elixir-ecto/ecto/blob/v3.0.4/lib/ecto/query/builder.ex#L221
  def unescape({:%, [], [Ecto.Query.Tagged, x]}), do: struct(Ecto.Query.Tagged, unescape(x))
  def unescape({x1, x2}), do: {unescape(x1), unescape(x2)}
  def unescape({x1,}), do: {unescape(x1),}
  def unescape(x) when is_list(x), do: Enum.map(x, &unescape/1)
  def unescape(x) when not is_tuple(x), do: x

  def query(query, opts) do
    clause = opts |> Keyword.new
    IO.inspect({query, opts})
    do_query_each(query, clause) |> IO.inspect
  end


  def do_query_each(query, [h | t]), do: query |> do_query(h |> IO.inspect(label: "do_query")) |> do_query_each(t)
  def do_query_each(query, []), do: query

  @doc """
  prefix: nil
  """
  def do_query(query, {:prefix, prefix}) do
    query = query |> Ecto.Queryable.to_query()
    put_in(query.prefix, prefix)
  end

  @doc """
  where: [[:role_id, "123"], [:grade, >, [:score, /, :total_count]]]
  """
  def do_query(query, {:where, where}) when is_list(where) do
    dynamic = to_quote_reduce(true, :and, where) |> build
    query |> Sql.where(^dynamic)
  end
  def do_query(query, {:where, where}) when is_binary(where) do
    dynamic = case Code.string_to_quoted(where) do
      {:ok, ast} -> build(ast)
      _ -> false
    end
    query |> Sql.where(^dynamic)
  end

  @doc """
  limit: 100
  """
  def do_query(query, {:limit, limit}) do
    query |> Sql.limit(^limit)
  end

  @doc """
  offset: 100
  """
  def do_query(query, {:offset, offset}) do
    query |> Sql.offset(^offset)
  end

  def to_quote_reduce(acc, op, [h | t]) do
    to_quote(op, acc, h) |> to_quote_reduce(op, t)
  end
  def to_quote_reduce(acc, _, []), do: acc

  def to_quote(i) when is_number(i) or is_boolean(i) do
    i
  end
  def to_quote(i) when is_atom(i) do
    to_quote(:., :x1, i)
  end
  def to_quote({lhs, rhs}) do
    to_quote(:==, lhs, rhs)
  end
  def to_quote({lhs, op, rhs}) when is_atom(op) do
    to_quote(op, lhs, rhs)
  end
  def to_quote(:., lhs, rhs) when is_atom(lhs) and is_atom(rhs) do
    {{:., [], [{lhs, [], nil}, rhs]}, [], []}
  end
  def to_quote(op, lhs, rhs) do
    {op, [], [to_quote(lhs), to_quote(rhs)]}
  end

  def find_binding(x) do
    find_binding([], x) |> Enum.uniq
  end
  def find_binding(acc, {x, _, a}) when is_atom(x) and (is_atom(a) or is_nil(a)) do
    [x | acc]
  end
  def find_binding(acc, {x, _, list}) when is_list(list) do
    acc = Enum.reduce(list, acc, fn x, acc -> find_binding(acc, x) end)
    find_binding(acc, x)
  end
  def find_binding(acc, _), do: acc
end