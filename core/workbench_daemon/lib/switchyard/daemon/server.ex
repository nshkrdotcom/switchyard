defmodule Switchyard.Daemon.Server do
  @moduledoc false
  use GenServer

  alias ExecutionPlane.OperatorTerminal
  alias Jido.Integration.V2
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
    request = Map.put_new(attrs, :id, "proc-#{System.unique_integer([:positive])}")

    case ProcessRuntime.spec(request) do
      {:ok, spec} ->
        preview_command = ProcessRuntime.preview_command(spec)

        case ProcessRuntime.start_managed(spec, self()) do
          {:ok, pid} ->
            process = %{
              id: spec.id,
              label: Map.get(attrs, :label, spec.id),
              status: "running",
              command: spec.command,
              command_preview: preview_command,
              args: spec.args,
              shell?: spec.shell?,
              cwd: spec.cwd,
              execution_surface: execution_surface_summary(spec),
              sandbox: sandbox_summary(spec),
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
            {:reply, {:error, %{reason: reason, command_preview: preview_command}}, state}
        end

      {:error, reason} ->
        {:reply,
         {:error, %{reason: reason, command_preview: ProcessRuntime.preview_command(request)}},
         state}
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
      jobs: state.jobs |> Map.values() |> Enum.sort_by(& &1.id),
      operator_terminals: operator_terminal_snapshot(),
      runs: jido_runs_snapshot(),
      boundary_sessions: jido_boundary_sessions_snapshot(),
      attach_grants: jido_attach_grants_snapshot()
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
      "jobs" => Enum.map(snapshot.jobs, &serialize_job/1),
      "operator_terminals" => Enum.map(snapshot.operator_terminals, &serialize_generic_map/1),
      "runs" => Enum.map(snapshot.runs, &serialize_generic_map/1),
      "boundary_sessions" => Enum.map(snapshot.boundary_sessions, &serialize_generic_map/1),
      "attach_grants" => Enum.map(snapshot.attach_grants, &serialize_generic_map/1)
    }
  end

  defp serialize_process(process) do
    process
    |> Map.take([
      :id,
      :label,
      :status,
      :command,
      :command_preview,
      :args,
      :shell?,
      :cwd,
      :execution_surface,
      :sandbox
    ])
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

  defp execution_surface_summary(%{execution_surface: execution_surface}) do
    transport_options =
      execution_surface.transport_options
      |> Enum.reduce(%{}, fn
        {key, value}, acc
        when key in [:host, :port, :user, :destination, :ssh_user, :identity_file, :ssh_path] ->
          Map.put(acc, to_string(key), value)

        {_key, _value}, acc ->
          acc
      end)

    %{
      "surface_kind" => Atom.to_string(execution_surface.surface_kind),
      "target_id" => execution_surface.target_id,
      "boundary_class" =>
        case execution_surface.boundary_class do
          nil -> nil
          value when is_atom(value) -> Atom.to_string(value)
          value -> to_string(value)
        end,
      "transport_options" => transport_options
    }
  end

  defp sandbox_summary(%{sandbox: sandbox}) do
    %{
      "mode" => Atom.to_string(sandbox.mode),
      "policy" => %{
        "writable_roots" => Map.get(sandbox.policy, :writable_roots),
        "network_access" =>
          case Map.get(sandbox.policy, :network_access) do
            value when is_atom(value) -> Atom.to_string(value)
            value -> value
          end,
        "has_command_prefix" =>
          sandbox.policy
          |> Map.get(:command_prefix, [])
          |> List.wrap()
          |> case do
            [] -> false
            _items -> true
          end
      }
    }
  end

  defp operator_terminal_snapshot do
    OperatorTerminal.list()
    |> Enum.map(fn info ->
      %{
        id: info.terminal_id,
        title: Atom.to_string(info.surface_kind),
        surface_kind: Atom.to_string(info.surface_kind),
        surface_ref: info.surface_ref,
        boundary_class: stringify_atomish(info.boundary_class),
        status: Atom.to_string(info.status),
        transport_options: stringify_map(info.transport_options),
        adapter_metadata: stringify_map(info.adapter_metadata)
      }
    end)
  rescue
    _error ->
      []
  end

  defp jido_runs_snapshot do
    V2.runs(%{})
    |> Enum.map(fn run ->
      %{
        id: run.run_id,
        capability_id: run.capability_id,
        runtime_class: Atom.to_string(run.runtime_class),
        status: Atom.to_string(run.status),
        target_id: run.target_id,
        tenant_id: credential_tenant_id(run),
        inserted_at: run.inserted_at
      }
    end)
  rescue
    _error ->
      []
  end

  defp jido_boundary_sessions_snapshot do
    V2.boundary_sessions(%{})
    |> Enum.map(fn session ->
      %{
        id: session.boundary_session_id,
        boundary_session_id: session.boundary_session_id,
        target_id: session.target_id,
        route_id: session.route_id,
        attach_grant_id: session.attach_grant_id,
        tenant_id: session.tenant_id,
        status: Atom.to_string(session.status),
        metadata: stringify_map(session.metadata),
        inserted_at: session.inserted_at
      }
    end)
  rescue
    _error ->
      []
  end

  defp jido_attach_grants_snapshot do
    V2.attach_grants(%{})
    |> Enum.map(fn attach_grant ->
      %{
        id: attach_grant.attach_grant_id,
        attach_grant_id: attach_grant.attach_grant_id,
        boundary_session_id: attach_grant.boundary_session_id,
        route_id: attach_grant.route_id,
        subject_id: attach_grant.subject_id,
        status: Atom.to_string(attach_grant.status),
        lease_expires_at: attach_grant.lease_expires_at,
        metadata: stringify_map(attach_grant.metadata),
        inserted_at: attach_grant.inserted_at
      }
    end)
  rescue
    _error ->
      []
  end

  defp credential_tenant_id(run) do
    run.credential_ref.metadata[:tenant_id] || run.credential_ref.metadata["tenant_id"]
  end

  defp serialize_generic_map(map), do: stringify_map(map)

  defp stringify_map(map) when is_map(map) do
    Enum.into(map, %{}, fn {key, value} -> {to_string(key), stringify_value(value)} end)
  end

  defp stringify_map(value), do: stringify_value(value)

  defp stringify_value(value) when is_map(value), do: stringify_map(value)
  defp stringify_value(value) when is_list(value), do: Enum.map(value, &stringify_value/1)
  defp stringify_value(value) when is_atom(value), do: Atom.to_string(value)
  defp stringify_value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp stringify_value(value), do: value

  defp stringify_atomish(nil), do: nil
  defp stringify_atomish(value) when is_atom(value), do: Atom.to_string(value)
  defp stringify_atomish(value), do: to_string(value)

  defp stream_id(process_id), do: "logs/#{process_id}"
end
