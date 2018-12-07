defmodule Jx3App.Model.Dynamic.Test do
  import Jx3App.Model.Dynamic
  require Ecto.Query

  defmacro assert(expr) do
    env = __CALLER__
    expr_string = Macro.to_string(expr)
    _fileinfo  = "#{env.file}:#{env.line}"
    quote do
      if not unquote(expr) do
        raise "Assert failed: " <> unquote(expr_string)
      else
        :ok
      end
    end
  end

  def macro_equal(x1, x2) do
    Macro.escape(x1, prune_metadata: true) == Macro.escape(x2, prune_metadata: true)
  end

  def test do
    expr1 = quote do true and x1.role_id < x1.global_id and x1.body_type == "little" end
    expr1_string = "true and x1.role_id() < x1.global_id() and x1.body_type() == \"little\""
    {:ok, _expr1} = Code.string_to_quoted expr1_string
    # assert macro_equal(expr1, expr1_2)
    assert expr1 |> Macro.to_string |>IO.inspect == expr1_string
    binding1 = find_binding(expr1) |> Enum.map(fn x -> {x, [], nil} end)
    assert binding1 == [{:x1, [], nil}]
    # dynamic_expr1_ecto = Ecto.Query.Builder.Dynamic.build(binding1, expr1, __ENV__) |> IO.inspect
    dynamic_expr1_ans = Ecto.Query.dynamic([x1], true and x1.role_id < x1.global_id and x1.body_type == "little")
    assert Macro.escape(expr1) |> unescape() == expr1
    escape_test_expr = %{a: [1,2,{3,[a: ""],5},{nil, %{}}], b: %{{6, 7, 8} => :c}}
    assert Macro.escape(escape_test_expr) |> unescape == escape_test_expr
    dynamic_expr1 = build(binding1, expr1, %{file: "<input>", line: 1}) |> IO.inspect
    assert macro_equal(dynamic_expr1_ans.binding, dynamic_expr1.binding)
    assert macro_equal(dynamic_expr1_ans.fun.(0), dynamic_expr1.fun.(0))
  end
end