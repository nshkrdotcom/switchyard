defmodule Switchyard.Daemon.Server do
  @moduledoc false
  use GenServer

  alias Switchyard.Contracts.{ActionResult, Job, LogEvent}
  alias Switchyard.JobRuntime
  alias Switchyard.LogRuntime
  alias Switchyard.Platform.Registry
  alias Switchyard.ProcessRuntime
  alias Switchyard.Store.Local

  @type state :: %{
          site_modules: [module()],
          processes: %{optional(String.t()) => map()},
          jobs: %{optional(String.t()) => Job.t()},
          logs: %{optional(String.t()) => LogRuntime.Buffer.t()},
          store_root: String.t() | nil
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    case Keyword.fetch(opts, :name) do
      {:ok, nil} -> GenServer.start_link(__MODULE__, opts)
      {:ok, name} -> GenServer.start_link(__MODULE__, opts, name: name)
      :error -> GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end
  end

  @impl true
  def init(opts) do
    state = %{
      site_modules: Keyword.get(opts, :site_modules, []),
      processes: %{},
      jobs: %{},
      logs: %{},
      store_root: Keyword.get(opts, :store_root)
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:list_sites, _from, state) do
    {:reply, Registry.sites(state.site_modules), state}
  end

  @impl true
  def handle_call({:list_apps, site_id}, _from, state) do
    {:reply, Registry.apps(site_id, state.site_modules), state}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, snapshot(state), state}
  end

  @impl true
  def handle_call({:logs, stream_id}, _from, state) do
    logs =
      state.logs
      |> Map.get(stream_id, LogRuntime.new_buffer(100))
      |> LogRuntime.recent()

    {:reply, logs, state}
  end

  @impl true
  def handle_call({:start_process, attrs}, _from, state) do
    spec =
      attrs
      |> Map.put_new(:id, "proc-#{System.unique_integer([:positive])}")
      |> Map.take([:id, :command, :cwd, :env])
      |> ProcessRuntime.spec!()

    case ProcessRuntime.start_managed(spec, self()) do
      {:ok, pid} ->
        process = %{
          id: spec.id,
          label: Map.get(attrs, :label, spec.id),
          status: "running",
          command: spec.command,
          pid: pid
        }

        job_id = "job-#{spec.id}"

        {:ok, job} =
          JobRuntime.new(%{id: job_id, kind: :process_start, title: "Start #{process.label}"})
          |> JobRuntime.transition(:running)

        new_state =
          state
          |> put_in([:processes, spec.id], process)
          |> put_in([:jobs, job_id], job)
          |> ensure_stream(spec.id)
          |> persist()

        {:reply,
         {:ok,
          ActionResult.new!(%{status: :accepted, message: "process started", job_id: job_id})},
         new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:stop_process, process_id}, _from, state) do
    case Map.fetch(state.processes, process_id) do
      {:ok, %{pid: pid} = process} ->
        GenServer.stop(pid, :normal)
        new_process = %{process | status: "stopped"}
        new_state = put_in(state, [:processes, process_id], new_process) |> persist()

        {:reply, {:ok, ActionResult.new!(%{status: :accepted, message: "process stopped"})},
         new_state}

      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:switchyard_request, %{kind: :sites}}, _from, state) do
    {:reply, Registry.sites(state.site_modules), state}
  end

  def handle_call({:switchyard_request, %{kind: :apps, site_id: site_id}}, _from, state) do
    {:reply, Registry.apps(site_id, state.site_modules), state}
  end

  def handle_call({:switchyard_request, %{kind: :local_snapshot}}, _from, state) do
    {:reply, snapshot(state), state}
  end

  def handle_call({:switchyard_request, %{kind: :start_process, spec: spec}}, _from, state) do
    handle_call({:start_process, spec}, self(), state)
  end

  def handle_call({:switchyard_request, %{kind: :logs, stream_id: stream_id}}, _from, state) do
    handle_call({:logs, stream_id}, self(), state)
  end

  @impl true
  def handle_info({:process_output, process_id, line}, state) do
    stream_id = stream_id(process_id)

    event =
      LogEvent.new!(%{
        at: DateTime.utc_now(),
        level: :info,
        source_kind: :process,
        source_id: process_id,
        stream_id: stream_id,
        message: line
      })

    new_state =
      update_in(state.logs[stream_id], &LogRuntime.append(&1, event))
      |> persist()

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:process_exit, process_id, status}, state) do
    stream_id = stream_id(process_id)
    job_id = "job-#{process_id}"

    new_state =
      state
      |> update_in([:processes, process_id], fn
        nil -> nil
        process -> %{process | status: if(status == 0, do: "succeeded", else: "failed"), pid: nil}
      end)
      |> update_in([:jobs, job_id], fn
        nil ->
          nil

        job ->
          next_status = if(status == 0, do: :succeeded, else: :failed)
          {:ok, updated_job} = JobRuntime.transition(job, next_status)
          updated_job
      end)
      |> update_in([:logs, stream_id], fn
        buffer ->
          event =
            LogEvent.new!(%{
              at: DateTime.utc_now(),
              level: if(status == 0, do: :info, else: :error),
              source_kind: :process,
              source_id: process_id,
              stream_id: stream_id,
              message: "process exited with status #{status}"
            })

          LogRuntime.append(buffer || LogRuntime.new_buffer(100), event)
      end)
      |> persist()

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:switchyard_notify, _payload}, state) do
    {:noreply, state}
  end

  defp ensure_stream(state, process_id) do
    update_in(state.logs[stream_id(process_id)], fn
      nil -> LogRuntime.new_buffer(100)
      buffer -> buffer
    end)
  end

  defp snapshot(state) do
    %{
      processes: state.processes |> Map.values() |> Enum.sort_by(& &1.id),
      jobs: state.jobs |> Map.values() |> Enum.sort_by(& &1.id)
    }
  end

  defp persist(%{store_root: nil} = state), do: state

  defp persist(%{store_root: root} = state) do
    Local.put_snapshot(root, "daemon", "local_snapshot", serialize_snapshot(snapshot(state)))
    state
  end

  defp serialize_snapshot(snapshot) do
    %{
      "processes" => Enum.map(snapshot.processes, &serialize_process/1),
      "jobs" => Enum.map(snapshot.jobs, &serialize_job/1)
    }
  end

  defp serialize_process(process) do
    process
    |> Map.take([:id, :label, :status, :command])
    |> Enum.into(%{}, fn {key, value} -> {Atom.to_string(key), value} end)
  end

  defp serialize_job(job) do
    %{
      "id" => job.id,
      "kind" => Atom.to_string(job.kind),
      "title" => job.title,
      "status" => Atom.to_string(job.status),
      "progress" => %{"current" => job.progress.current, "total" => job.progress.total}
    }
  end

  defp stream_id(process_id), do: "logs/#{process_id}"
end
