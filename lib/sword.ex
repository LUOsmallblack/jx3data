defmodule Jx3App.Sword.SwordRepo do
  use Ecto.Repo,
    otp_app: :jx3app,
    adapter: Ecto.Adapters.Postgres,
    priv: "priv/sword_repo"
end

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
  def handle_call({:result, msg_id}, _from, {_, _, responses} = state) do
    result = responses[msg_id]
    {:reply, result, state}
  end

  @impl true
  def handle_cast({:response, channel, msg}, {port, requests, responses}) do
    msg_id = msg["parent_header"]["msg_id"]
    msg_type = msg["msg_type"]
    case requests[msg_id] do
      %{} = request ->
        case request.from do
          {pid, _} -> send(pid, {:jupyter_result, msg_id, channel, msg_type, msg})
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
    end |> IO.inspect(label: "Receive Loop")
    do_receive_loop(hub, port)
  end

  def do_init(hub) do
    port = Port.open({:spawn, "python3 jupyter/client.py"}, [:binary, cd: "analyze", line: 4096])
    IO.inspect({self(), port, hub}, label: "spawn_link")
    send(hub, {self(), {:jupyter_connected, port}})
    do_receive_loop(hub, port)
  end

  def port_send({pid, port}, channel, msg_type, content) do
    resp_type = Atom.to_string(msg_type) |> String.replace_trailing("_request", "_reply") |> String.to_atom
    send(port, {pid, {:command, "#{channel}>#{Jason.encode!([msg_type, content])}\n"}})
    msg_id =
      receive do
        {^pid, {:msgid, msgid}} -> msgid
      end
    %Request{msg_id: msg_id, from: nil, channel: channel, req_type: msg_type, resp_type: resp_type, content: content}
  end

  def port_receive(port, opts \\ []) do
    verbose = opts[:verbose] || true
    receive do
      {^port, {:data, {:eol, << "msgid>", msgid::binary >>}}} ->
        msgid = case Jason.decode(msgid) do
          {:ok, m} -> m
          _ -> msgid
        end
        {:msgid, msgid} |> IO.inspect(label: "recv")
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
      [channel, json] ->
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

defmodule Jx3App.Sword.Data do
  alias Jx3App.Sword.SwordRepo, as: Repo

  use JuliaPort.GenFunction, [connect_spark: 1, load_db: 3]

  def port_init do
    {:ok, port} = GenServer.start_link(Jx3App.JupyterClient, [])
    port
  end

  def execute(port, code) do
    {:ok, request} = GenServer.call(port, {:execute, code})
    {port, request}
  end

  def result({port, request}), do: result(port, request.msg_id)

  def result(port, msg_id) do
    GenServer.call(port, {:result, msg_id})
  end

  def init do
    spark_master = Application.get_env(:jx3app, __MODULE__)[:spark_master] || "localhost"
    port = port_init()
    port |> execute(~s|import Pkg; Pkg.activate(".")|) |> result()
    "" = port |> execute("using Sword") |> result()
    "" = port |> execute("Sword.init()") |> result()
    # port |> connect_spark(:spark, spark_master) |> result() |> IO.inspect(label: "connect_spark")
    port
  end

  def table(port, name) do
    # db_url = Application.get_env(:jx3app, __MODULE__)[:spark_master] || "localhost:5732/jx3app"
    # port |> load_db(String.to_atom(name), :spark, db_url, name) |> port_receive()
  end
end