defmodule Jx3App.JupyterClient do
  defmodule Request do
    defstruct [:msg_id, :from, :channel, :req_type, :content, :resp_type]
  end

  use GenServer

  @impl true
  def init(_) do
    port = port_init()
    {:ok, {port, %{}, %{}}}
  end

  @impl true
  def handle_call({:execute, code}, from, {port, requests, responses}) do
    request = %{port |> execute(code) | from: from} |> IO.inspect
    {:reply, request, {port, Map.put(requests, request.msg_id, request), responses}}
  end

  @impl true
  def handle_call({:results, msg_id}, _from, {_, _, responses} = state) do
    result = responses[msg_id]
    {:reply, result, state}
  end

  @impl true
  def handle_cast({:response, channel, msg}, {port, requests, responses}) do
    msg_id = msg["parent_header"]["msg_id"]
    msg_type = msg["msg_type"]
    case {channel, msg_type} do
      {:iopub, "stream"} -> IO.puts(msg["content"]["text"] || "")
      {:iopub, _} -> IO.inspect({msg_id, msg_type, msg["content"]})
      _ -> :ok
    end
    case requests[msg_id] do
      %{} = request ->
        case request.from do
          {pid, _} -> send(pid, {self(), {:jupyter_result, msg_id, channel, msg_type, msg}})
          _ -> :error
        end
      _ -> :error
    end
    resps = responses[msg_id] || []
    {:noreply, {port, requests, Map.put(responses, msg_id, [msg | resps])}}
  end

  def port_init do
    hub = self()
    spawn_link(fn -> do_init(hub) end)
    receive do
      {pid, {:jupyter_connected, port}} -> {pid, port} |> IO.inspect
    end
  end

  def do_receive_loop(hub, port) do
    case port_receive(port) do
      {:msgid, msgid} -> send(hub, {self(), {:msgid, msgid}} |> IO.inspect(label: "send_msgid"))
      {channel, %{} = body} -> GenServer.cast(hub, {:response, channel, body})
      _ -> :error
    end
    do_receive_loop(hub, port)
  end

  def do_init(hub) do
    port = Port.open({:spawn, "python3 -u jupyter/client.py"}, [:binary, cd: "analyze", line: 4096])
    IO.inspect({self(), port, hub}, label: "spawn_link")
    send(hub, {self(), {:jupyter_connected, port}})
    do_receive_loop(hub, port)
  end

  def port_send({pid, port}, channel, msg_type, content) do
    resp_type = Atom.to_string(msg_type) |> String.replace_trailing("_request", "_reply")
    send(port, {pid, {:command, "|#{channel}>#{Jason.encode!([msg_type, content])}\n"}})
    msg_id =
      receive do
        {^pid, {:msgid, msgid}} -> msgid
      end
    %Request{msg_id: msg_id, from: nil, channel: channel, req_type: msg_type, resp_type: resp_type, content: content}
  end

  def port_receive(port, opts \\ []) do
    verbose = opts[:verbose] || false
    receive do
      {^port, {:data, {:eol, << "msgid>", msgid::binary >>}}} ->
        msgid = case Jason.decode(msgid) do
          {:ok, m} -> m
          _ -> msgid
        end
        if verbose do IO.inspect(msgid, label: "msg_id") end
        {:msgid, msgid}
      {^port, {:data, x}} ->
        if verbose do IO.inspect(x, label: "recv") end
        case x do
          {:noeol, t} -> loop_receive(port, t, opts)
          {:eol, t} -> t
        end |> parse_recv
      x -> IO.inspect(x, label: "recv_unknown")
    end
  end

  def loop_receive(port, acc, opts) do
    receive do
      {^port, {:data, {:noeol, t}}} -> loop_receive(port, acc <> t, opts)
      {^port, {:data, {:eol, t}}} -> acc <> t
    end
  end

  def parse_recv(line) do
    case String.split(line, ">", parts: 2) do
      ["|" <> channel, json] ->
        case Jason.decode(json) do
          {:ok, body} -> {String.to_atom(channel), body}
          _ -> :error
        end
      _ -> :error
    end
  end

  def execute(port, code, opts \\ []) do
    content = %{
      code: code,
      silent: opts[:silent] || false,
      store_history: opts[:store_history] || true,
      user_expressions: opts[:user_expressions] || %{},
      allow_stdin: opts[:allow_stdin] || false,
      stop_on_error: opts[:stop_on_error] || false,
    }
    port_send(port, :shell, :execute_request, content)
  end
end

defmodule Jx3App.Sword.Process do
  alias Jx3App.Sword.SwordRepo, as: Repo

  def port_init do
    {:ok, port} = GenServer.start_link(Jx3App.JupyterClient, [])
    port
  end

  def execute(port, code) do
    {port, GenServer.call(port, {:execute, code})}
  end

  def results({port, request}), do: results(port, request.msg_id)

  def results(port, msg_id) do
    GenServer.call(port, {:result, msg_id})
  end

  def do_result(port, msg_id, channel, msg_type, opts \\ []) do
    cond do
      Keyword.get(opts, :multiple, false) ->
        timeout = opts[:timeout] || 0
        content = receive do
          {^port, {:jupyter_result, ^msg_id, ^channel, ^msg_type, msg}} ->
            msg["content"]
          after timeout -> :timeout
        end
        acc = opts[:acc] || []
        case content do
          :timeout -> acc
          _ ->
            opts = Keyword.put(opts, :acc, [content | acc])
            do_result(port, msg_id, channel, msg_type, opts)
        end
      Keyword.get(opts, :timeout) != nil ->
        timeout = opts[:timeout]
        receive do
          {^port, {:jupyter_result, ^msg_id, ^channel, ^msg_type, msg}} ->
            msg["content"]
          after timeout -> :timeout
        end
      true ->
        receive do
          {^port, {:jupyter_result, ^msg_id, ^channel, ^msg_type, msg}} ->
            msg["content"]
        end
    end
  end

  def result(port, msg_id, channel, msg_type, opts \\ [])
  def result(port, msg_id, channel, msg_type, opts) when is_binary(msg_id) do
    content = do_result(port, msg_id, channel, msg_type, opts)
    content = case opts[:others] do
      nil -> content
      others ->
        others = others |> Enum.map(fn
          {channel, msg_type, opts} -> do_result(port, msg_id, channel, msg_type, opts)
          {channel, msg_type} -> do_result(port, msg_id, channel, msg_type)
        end)
        {content, others}
    end
    if Keyword.get(opts, :clean, true) do
      receive do
        {^port, {:jupyter_result, ^msg_id, _, _, _}} -> :dropped
      end
    end
    content
  end
  def result(_port, _msg_id, _channel, _msg_type, _others), do: :error

  def result({port, request}, opts \\ []) do
    result(port, request.msg_id, request.channel, request.resp_type, opts)
  end

  def execute_result({port, request}, opts \\ []) do
    others = opts[:others] || []
    opts = opts |> Keyword.put(:others, [{:iopub, "execute_result", multiple: true} | others])
    {content, [output|others]} = result({port, request}, opts)
    if others == [] do
      {content, output}
    else
      {content, output, others}
    end |> IO.inspect
  end

  def init(port) do
    spark_master = Application.get_env(:jx3app, __MODULE__)[:spark_master] || "localhost"
    port |> execute(~s|import Pkg; Pkg.activate(".")|) |> execute_result()
    {%{"status" => "ok"}, []} = port |> execute("using Sword") |> execute_result()
    {%{"status" => "ok"}, []} = port |> execute("Sword.init()") |> execute_result()
    port
  end

  def run(port, filename) do
    port |> execute(~s|include("#{filename}")|) |> execute_result() |> IO.inspect(label: "run #{filename}")
    port
  end

  def run_task(port) do
    files = ["test.jl"] |> Enum.zip(Stream.cycle([port]))
    Jx3App.Task.start_task(:sword_process, files, fn {filename, port} -> run(port, filename) end, nil)
  end
end
