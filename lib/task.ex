defmodule Jx3App.Task do
  @name __MODULE__

  require Logger

  def start_link() do
    Agent.start_link(fn -> load() end, name: @name)
  end

  def load do
    %{}
  end

  def keys do
    Agent.get(@name, fn tasks ->
      Map.keys(tasks)
    end)
  end

  def get(name) do
    Agent.get(@name, fn tasks ->
      case Map.get(tasks, name, nil) do
        %{status: status} = t -> {status, t}
        nil -> {:not_exist, nil}
      end
    end)
  end

  def put(name, t) do
    Agent.update(@name, fn tasks ->
      Map.put(tasks, name, t)
    end)
  end

  def update_status(name, status) do
    Agent.update(@name, fn tasks ->
      Map.update(tasks, name, nil, fn %{status: old_status} = t ->
        case {old_status, status} do
          {:stopped, :stopping} -> t
          {:finished, :stopping} -> t
          {:stopping, :finished} -> %{t | status: :stopped}
          {:stopping, _} -> t
          _ -> %{t | status: status}
        end
      end)
    end)
  end

  def start_task(name, list, func, parent) do
    count = Enum.count(list)
    task = %{name: name, list: list, func: func, parent: parent, count: count, status: :not_started}
    case get(name) do
      {:not_exist, _} -> start_task(task)
      {:finished, _} -> start_task(task)
      {:stopped, _} -> start_task(task)
      _ -> {:error, "task exists"}
    end
  end

  def start_task(%{name: name, list: list, func: func, parent: parent, count: count, status: :not_started} = t) do
    put(name, t)
    {:ok, task} = Task.start(fn ->
      update_status(name, :started)
      list
      |> Stream.with_index
      |> Enum.each(fn {x, i} ->
        try do
          case get(name) do
            {:stopping, _} -> :skipped
            _ -> func.(x)
          end
          update_status(name, {:partial, i, count})
        rescue
          e ->
            Logger.error("Jx3App.Task (#{name}): " <> Exception.format(:error, e, __STACKTRACE__))
        catch
          :exit, e when e != :stop -> {:error, e}
        end
      end)
      update_status(name, :finished)
    end)
    Agent.update(@name, fn tasks -> put_in(tasks, [name, :task], task) end)
    task
  end

  def stop(name) do
    update_status(name, :stopping)
  end

  def do_resume(name, i, %{list: list, count: count, task: task} = t) do
    if not Process.alive?(task) do
      update_status(name, :finished)
      update_status(name, :stopped)
      start_task(%{t | list: list |> Enum.drop(i), count: count-i, status: :not_started})
    else
      :ok
    end
  end

  def resume(name) do
    case get(name) do
      {:started, %{} = t} -> do_resume(name, 0, t)
      {{:partial, i, _}, %{} = t} -> do_resume(name, i, t)
      _ -> :error
    end
  end

  def kill(name) do
    case get(name) do
      {:not_exist, _} -> :error
      {:finished, _} -> :ok
      {:stopped, _} -> :ok
      {_, %{task: task}} ->
        Process.exit(task, :stop)
        update_status(name, :finished)
        update_status(name, :stopped)
      _ -> :error
    end
  end
end
