defmodule Switchyard.Daemon.Server do
  @moduledoc false
  use GenServer

  alias ExecutionPlane.OperatorTerminal
  alias Jido.Integration.V2
  alias Switchyard.Contracts.{Action, ActionResult, Job, LogEvent, Resource, StreamDescriptor}
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
          streams: %{optional(String.t()) => StreamDescriptor.t()},
          stream_sequences: %{optional(String.t()) => non_neg_integer()},
          recovery_status: map(),
          daemon_instance_id: String.t(),
          store_root: String.t() | nil
        }

  @schema_version 1
  @current_snapshot "current"
  @current_journal "journal-current"
  @resource_kind_strings %{
    "attach_grant" => :attach_grant,
    "boundary_session" => :boundary_session,
    "job" => :job,
    "log_stream" => :log_stream,
    "operator_terminal" => :operator_terminal,
    "process" => :process,
    "run" => :run,
    "site_state" => :site_state,
    "stream" => :stream,
    "workspace" => :workspace
  }
  @log_level_strings %{
    "debug" => :debug,
    "error" => :error,
    "info" => :info,
    "warn" => :warn,
    "warning" => :warning
  }
  @log_source_kind_strings %{
    "daemon" => :daemon,
    "job" => :job,
    "operator_terminal" => :operator_terminal,
    "process" => :process,
    "site" => :site,
    "stream" => :stream
  }
  @atomish_strings %{
    "accepted" => :accepted,
    "attach_grant" => :attach_grant,
    "available" => :available,
    "boundary_session" => :boundary_session,
    "bounded" => :bounded,
    "cancelled" => :cancelled,
    "canceled" => :canceled,
    "completed" => :completed,
    "daemon_restarted_without_reconnect" => :daemon_restarted_without_reconnect,
    "debug" => :debug,
    "degraded" => :degraded,
    "empty" => :empty,
    "error" => :error,
    "exit_nonzero" => :exit_nonzero,
    "exit_zero" => :exit_zero,
    "failed" => :failed,
    "filter" => :filter,
    "id" => :id,
    "info" => :info,
    "issued" => :issued,
    "job" => :job,
    "job_events" => :job_events,
    "local_subprocess" => :local_subprocess,
    "lost" => :lost,
    "memory_only" => :memory_only,
    "operator_requested" => :operator_requested,
    "operator_terminal" => :operator_terminal,
    "pending" => :pending,
    "process" => :process,
    "process_combined" => :process_combined,
    "process_id" => :process_id,
    "process_stop" => :process_stop,
    "queued" => :queued,
    "retention" => :retention,
    "run" => :run,
    "running" => :running,
    "site_id" => :site_id,
    "site_state" => :site_state,
    "ssh_exec" => :ssh_exec,
    "stopped" => :stopped,
    "stream" => :stream,
    "succeeded" => :succeeded,
    "tail" => :tail,
    "terminal" => :terminal,
    "unknown" => :unknown,
    "unavailable" => :unavailable,
    "warn" => :warn,
    "warning" => :warning,
    "workspace" => :workspace
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
      daemon_instance_id:
        Keyword.get_lazy(opts, :daemon_instance_id, fn ->
          "daemon-#{System.unique_integer([:positive])}"
        end),
      site_modules: Keyword.get(opts, :site_modules, []),
      processes: %{},
      jobs: %{},
      logs: %{},
      streams: %{},
      stream_sequences: %{},
      recovery_status: memory_only_recovery_status(),
      store_root: Keyword.get(opts, :store_root)
    }

    case recover_from_store(state) do
      {:ok, recovered_state} -> {:ok, recovered_state}
      {:error, reason} -> {:stop, {:recovery_failed, reason}}
    end
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
    {:reply, logs_for_stream(state, stream_id), state}
  end

  @impl true
  def handle_call({:start_process, attrs}, _from, state) do
    {reply, new_state} = execute_process_action(state, :start, attrs)
    {:reply, reply, new_state}
  end

  @impl true
  def handle_call({:stop_process, process_id}, _from, state) do
    {reply, new_state} = execute_process_action(state, :stop, %{"process_id" => process_id})
    {:reply, reply, new_state}
  end

  @impl true
  def handle_call({:switchyard_request, %{kind: :sites}}, _from, state) do
    {:reply, Registry.sites(state.site_modules), state}
  end

  def handle_call({:switchyard_request, %{kind: :apps, site_id: site_id}}, _from, state) do
    {:reply, Registry.apps(site_id, state.site_modules), state}
  end

  def handle_call({:switchyard_request, %{kind: :actions, resource: resource_ref}}, _from, state) do
    reply =
      case normalize_resource_ref(resource_ref) do
        {:ok, resource} ->
          Registry.actions_for_resource(resource, state.site_modules, snapshot(state))

        {:error, reason} ->
          {:error, reason}
      end

    {:reply, reply, state}
  end

  def handle_call({:switchyard_request, %{kind: :actions, site_id: site_id}}, _from, state) do
    {:reply, Registry.actions(site_id, state.site_modules), state}
  end

  def handle_call({:switchyard_request, %{kind: :actions}}, _from, state) do
    {:reply, Registry.actions(state.site_modules), state}
  end

  def handle_call({:switchyard_request, %{kind: :local_snapshot}}, _from, state) do
    {:reply, snapshot(state), state}
  end

  def handle_call({:switchyard_request, %{kind: :streams, resource: resource_ref}}, _from, state) do
    reply =
      case normalize_resource_ref(resource_ref) do
        {:ok, resource} -> streams_for_resource(state, resource)
        {:error, reason} -> {:error, reason}
      end

    {:reply, reply, state}
  end

  def handle_call({:switchyard_request, %{kind: :streams}}, _from, state) do
    {:reply, state.streams |> Map.values() |> Enum.sort_by(& &1.id), state}
  end

  def handle_call({:switchyard_request, %{kind: :start_process, spec: spec}}, _from, state) do
    {reply, new_state} = execute_process_action(state, :start, spec)
    {:reply, reply, new_state}
  end

  def handle_call({:switchyard_request, %{kind: :execute_action} = payload}, _from, state) do
    {reply, new_state} = execute_action_request(payload, state)
    {:reply, reply, new_state}
  end

  def handle_call(
        {:switchyard_request, %{kind: :logs, stream_id: stream_id} = payload},
        _from,
        state
      ) do
    {:reply, logs_for_stream(state, stream_id, log_opts(payload)), state}
  end

  def handle_call({:switchyard_request, payload}, _from, state) do
    {:reply,
     {:error,
      %{
        reason: :unknown_request,
        request: payload,
        message: "unknown request"
      }}, state}
  end

  @impl true
  def handle_info({:process_output, process_id, line}, state) do
    handle_info({:process_output, process_id, line, %{}}, state)
  end

  def handle_info({:process_output, process_id, line, fields}, state) do
    stream_id = stream_id(process_id)

    event =
      LogEvent.new!(%{
        at: DateTime.utc_now(),
        level: :info,
        source_kind: :process,
        source_id: process_id,
        stream_id: stream_id,
        message: line,
        fields: Map.put_new(fields, :process_id, process_id)
      })

    new_state =
      state
      |> append_log_event(event)
      |> update_in([:processes, process_id], fn
        nil -> nil
        process -> %{process | last_seen_at: event.at}
      end)
      |> persist()

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:process_exit, process_id, status}, state) do
    stream_id = stream_id(process_id)
    job_id = "job-#{process_id}"
    now = DateTime.utc_now()
    next_status = if(status == 0, do: :succeeded, else: :failed)
    status_reason = if(status == 0, do: :exit_zero, else: :exit_nonzero)

    new_state =
      state
      |> update_in([:processes, process_id], fn
        nil ->
          nil

        process ->
          %{
            process
            | status: next_status,
              status_reason: status_reason,
              exit_status: status,
              stopped_at: now,
              last_seen_at: now,
              pid: nil
          }
      end)
      |> update_in([:jobs, job_id], fn
        nil ->
          nil

        job ->
          {:ok, updated_job} = JobRuntime.transition(job, next_status)
          updated_job
      end)
      |> append_log_event(
        LogEvent.new!(%{
          at: now,
          level: if(status == 0, do: :info, else: :error),
          source_kind: :process,
          source_id: process_id,
          stream_id: stream_id,
          message: "process exited with status #{status}",
          fields: %{event_kind: :process_exit, process_id: process_id, exit_status: status}
        })
      )
      |> maybe_append_job_event(
        job_id,
        next_status,
        process_id,
        if(status == 0, do: :info, else: :error)
      )
      |> persist()

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:switchyard_notify, _payload}, state) do
    {:noreply, state}
  end

  defp execute_process_action(state, verb, input) when verb in [:start, :stop] do
    case process_action(state, verb) do
      nil ->
        {{:error,
          %{
            reason: :unsupported_capability,
            message: "process #{verb} action is not registered"
          }}, state}

      %Action{} = action ->
        payload =
          case verb do
            :start ->
              %{
                kind: :execute_action,
                action_id: action.id,
                site_id: action_site_id(action, state),
                input: input
              }

            :stop ->
              process_id = fetch(input, :process_id)

              %{
                kind: :execute_action,
                action_id: action.id,
                resource: %{
                  site_id: action_site_id(action, state),
                  kind: :process,
                  id: process_id
                },
                input: input,
                confirmed?: true
              }
          end

        execute_action_request(payload, state)
    end
  end

  defp execute_action_request(payload, state) do
    action_id = fetch(payload, :action_id)

    case Registry.fetch_action(action_id || "", state.site_modules) do
      :error ->
        {{:error,
          %{
            reason: :unknown_action,
            action_id: action_id,
            message: "unknown action"
          }}, state}

      {:ok, action} ->
        execute_known_action(action, payload, state)
    end
  end

  defp execute_known_action(action, payload, state) do
    with {:ok, input} <- normalize_input(fetch(payload, :input, %{}), action),
         {:ok, resource} <- normalize_resource_ref(fetch(payload, :resource)),
         {:ok, context} <- action_context(action, payload, input, resource, state),
         :ok <- validate_scope(action, context),
         :ok <- validate_resource_exists(action, context, state),
         :ok <- validate_input(action, input),
         :ok <- validate_confirmation(action, payload) do
      dispatch_action(action, input, context, state)
    else
      {:error, error} -> {{:error, error}, state}
    end
  end

  defp dispatch_action(%Action{id: id} = action, input, context, state)
       when is_binary(id) do
    cond do
      String.ends_with?(id, ".process.start") ->
        do_start_process(input, state)

      String.ends_with?(id, ".process.stop") ->
        do_stop_process(fetch(input, :process_id) || fetch(context_resource(context), :id), state)

      String.ends_with?(id, ".process.force_stop") ->
        unsupported_lifecycle_action(action, state)

      String.ends_with?(id, ".process.signal") ->
        unsupported_lifecycle_action(action, state)

      String.ends_with?(id, ".process.restart") ->
        restart_requires_explicit_spec(action, state)

      true ->
        dispatch_provider_action(action, input, context, state)
    end
  end

  defp dispatch_provider_action(%Action{} = action, input, context, state) do
    provider = action.provider

    if function_exported?(provider, :execute_action, 3) do
      case provider.execute_action(action.id, input, context) do
        {:ok, %ActionResult{} = result} ->
          {{:ok, result}, state}

        {:error, reason} ->
          {{:error,
            %{
              reason: :provider_error,
              action_id: action.id,
              provider: provider,
              detail: reason,
              message: "provider action failed"
            }}, state}

        other ->
          {{:error,
            %{
              reason: :invalid_action_result,
              action_id: action.id,
              provider: provider,
              detail: other,
              message: "provider returned an invalid action result"
            }}, state}
      end
    else
      {{:error,
        %{
          reason: :unsupported_capability,
          action_id: action.id,
          provider: provider,
          message: "provider does not execute actions"
        }}, state}
    end
  end

  defp do_start_process(attrs, state) do
    request =
      if fetch(attrs, :id) do
        attrs
      else
        Map.put(attrs, :id, "proc-#{System.unique_integer([:positive])}")
      end

    case ProcessRuntime.spec(request) do
      {:ok, spec} ->
        preview_command = ProcessRuntime.preview_command(spec)

        case ProcessRuntime.start_managed(spec, self()) do
          {:ok, pid} ->
            now = DateTime.utc_now()
            job_id = "job-#{spec.id}"
            stream_id = stream_id(spec.id)
            job_stream_id = job_stream_id(job_id)

            process = %{
              id: spec.id,
              label: fetch(attrs, :label, spec.id),
              status: :running,
              status_reason: :runtime_started,
              exit_status: nil,
              started_at: now,
              stopped_at: nil,
              last_seen_at: now,
              command: spec.command,
              command_preview: redact_command_preview(preview_command, spec),
              args: spec.args,
              shell?: spec.shell?,
              cwd: spec.cwd,
              env_summary: env_summary(spec),
              execution_surface: execution_surface_summary(spec),
              sandbox: sandbox_summary(spec),
              pid: pid,
              job_ids: [job_id],
              stream_ids: [stream_id, job_stream_id]
            }

            {:ok, job} =
              JobRuntime.new(%{
                id: job_id,
                kind: :process_start,
                title: "Start #{process.label}",
                related_resources: [process_resource_ref(spec.id)]
              })
              |> JobRuntime.transition(:running)

            new_state =
              state
              |> put_in([:processes, spec.id], process)
              |> put_in([:jobs, job_id], job)
              |> ensure_stream(spec.id)
              |> ensure_job_stream(job_id, spec.id)
              |> append_job_event(job_id, :running, spec.id, :info)
              |> persist()

            {{:ok,
              ActionResult.new!(%{
                status: :accepted,
                message: "process started",
                job_id: job_id,
                resource_ref: process_resource_ref(spec.id),
                output: %{stream_ids: [stream_id, job_stream_id]}
              })}, new_state}

          {:error, reason} ->
            {{:error, %{reason: reason, command_preview: preview_command}}, state}
        end

      {:error, reason} ->
        {{:error, %{reason: reason, command_preview: ProcessRuntime.preview_command(request)}},
         state}
    end
  end

  defp do_stop_process(process_id, state) do
    case Map.fetch(state.processes, process_id) do
      {:ok, %{pid: pid} = process} when is_pid(pid) ->
        stop_runtime_process(pid)
        {job_id, job} = stop_job(process_id, process)
        now = DateTime.utc_now()

        new_process =
          process
          |> Map.merge(%{
            status: :stopped,
            status_reason: :operator_requested,
            stopped_at: now,
            last_seen_at: now,
            pid: nil
          })
          |> append_process_job(job_id)

        new_state =
          state
          |> put_in([:processes, process_id], new_process)
          |> put_in([:jobs, job_id], job)
          |> ensure_job_stream(job_id, process_id)
          |> append_job_event(job_id, :succeeded, process_id, :info)
          |> persist()

        {{:ok,
          ActionResult.new!(%{status: :accepted, message: "process stopped", job_id: job_id})},
         new_state}

      {:ok, process} ->
        {job_id, job} = stop_job(process_id, process)
        now = DateTime.utc_now()

        new_process =
          process
          |> Map.merge(%{
            status: :stopped,
            status_reason: :operator_requested,
            stopped_at: now,
            last_seen_at: now,
            pid: nil
          })
          |> append_process_job(job_id)

        new_state =
          state
          |> put_in([:processes, process_id], new_process)
          |> put_in([:jobs, job_id], job)
          |> ensure_job_stream(job_id, process_id)
          |> append_job_event(job_id, :succeeded, process_id, :info)
          |> persist()

        {{:ok,
          ActionResult.new!(%{status: :accepted, message: "process stopped", job_id: job_id})},
         new_state}

      :error ->
        {{:error,
          %{
            reason: :not_found,
            process_id: process_id,
            message: "process not found"
          }}, state}
    end
  end

  defp unsupported_lifecycle_action(action, state) do
    {{:error,
      %{
        reason: :unsupported_capability,
        action_id: action.id,
        retryable?: false,
        message: "process lifecycle action is not supported by the active transport"
      }}, state}
  end

  defp restart_requires_explicit_spec(action, state) do
    {{:error,
      %{
        reason: :restart_requires_explicit_spec,
        action_id: action.id,
        retryable?: true,
        message: "restart requires an explicit safe restart spec"
      }}, state}
  end

  defp action_context(action, payload, input, resource, state) do
    site_id = fetch(payload, :site_id) || action_site_id(action, state)

    {:ok,
     %{
       action_id: action.id,
       site_id: site_id,
       app_id: fetch(payload, :app_id),
       resource: resource,
       input: input,
       snapshot: snapshot(state)
     }}
  end

  defp validate_scope(%Action{scope: {:global, _namespace}}, _context), do: :ok

  defp validate_scope(%Action{scope: {:site, site_id}} = action, %{site_id: request_site_id}) do
    if request_site_id in [nil, site_id] do
      :ok
    else
      {:error, scope_mismatch(action)}
    end
  end

  defp validate_scope(%Action{scope: {:app, app_id}} = action, %{app_id: request_app_id}) do
    if request_app_id == app_id do
      :ok
    else
      {:error, scope_mismatch(action)}
    end
  end

  defp validate_scope(%Action{scope: {:resource, kind}} = action, %{resource: resource}) do
    case resource do
      %Resource{kind: ^kind} -> :ok
      _other -> {:error, scope_mismatch(action)}
    end
  end

  defp validate_scope(
         %Action{scope: {:resource_instance, site_id, kind, resource_id}} = action,
         %{resource: resource}
       ) do
    case resource do
      %Resource{site_id: ^site_id, kind: ^kind, id: ^resource_id} -> :ok
      _other -> {:error, scope_mismatch(action)}
    end
  end

  defp scope_mismatch(action) do
    %{
      reason: :scope_mismatch,
      action_id: action.id,
      message: "action scope does not match request context"
    }
  end

  defp validate_resource_exists(%Action{scope: {:resource, _kind}} = action, context, state) do
    validate_context_resource_exists(action, context, state)
  end

  defp validate_resource_exists(
         %Action{scope: {:resource_instance, _site_id, _kind, _id}} = action,
         context,
         state
       ) do
    validate_context_resource_exists(action, context, state)
  end

  defp validate_resource_exists(_action, _context, _state), do: :ok

  defp validate_context_resource_exists(action, %{resource: %Resource{} = resource}, state) do
    if resource_exists?(resource, state) do
      :ok
    else
      {:error,
       %{
         reason: :resource_not_found,
         action_id: action.id,
         resource: resource_ref(resource),
         message: "resource not found"
       }}
    end
  end

  defp validate_context_resource_exists(action, _context, _state) do
    {:error, scope_mismatch(action)}
  end

  defp validate_input(%Action{input_schema: schema} = action, input) do
    required = Map.get(schema, "required", Map.get(schema, :required, []))

    missing =
      required
      |> List.wrap()
      |> Enum.map(&to_string/1)
      |> Enum.reject(&input_key?(input, &1))

    if missing == [] do
      :ok
    else
      {:error,
       %{
         reason: :invalid_input,
         action_id: action.id,
         missing: missing,
         message: "missing required input"
       }}
    end
  end

  defp validate_confirmation(%Action{confirmation: :never}, _payload), do: :ok

  defp validate_confirmation(%Action{} = action, payload) do
    if fetch(payload, :confirmed?, false) do
      :ok
    else
      {:error,
       %{
         reason: :confirmation_required,
         action_id: action.id,
         retryable?: true,
         message: "action requires confirmation"
       }}
    end
  end

  defp normalize_input(input, _action) when is_map(input), do: {:ok, input}

  defp normalize_input(input, action) do
    {:error,
     %{
       reason: :invalid_input,
       action_id: action.id,
       detail: input,
       message: "action input must be a map"
     }}
  end

  defp normalize_resource_ref(nil), do: {:ok, nil}
  defp normalize_resource_ref(%Resource{} = resource), do: {:ok, resource}

  defp normalize_resource_ref(%{} = attrs) do
    with site_id when is_binary(site_id) <- fetch(attrs, :site_id),
         {:ok, kind} <- normalize_resource_kind(fetch(attrs, :kind)),
         id when is_binary(id) <- fetch(attrs, :id) do
      {:ok,
       Resource.new!(%{
         site_id: site_id,
         kind: kind,
         id: id,
         title: fetch(attrs, :title, id)
       })}
    else
      _other ->
        {:error,
         %{
           reason: :invalid_resource,
           resource: attrs,
           message: "invalid resource reference"
         }}
    end
  end

  defp normalize_resource_ref(resource) do
    {:error,
     %{
       reason: :invalid_resource,
       resource: resource,
       message: "invalid resource reference"
     }}
  end

  defp normalize_resource_kind(kind) when is_atom(kind), do: {:ok, kind}

  defp normalize_resource_kind(kind) when is_binary(kind) do
    case Map.fetch(@resource_kind_strings, kind) do
      {:ok, atom} -> {:ok, atom}
      :error -> {:error, :invalid_resource_kind}
    end
  end

  defp normalize_resource_kind(_kind), do: {:error, :invalid_resource_kind}

  defp resource_exists?(%Resource{kind: :process, id: process_id}, state) do
    Map.has_key?(state.processes, process_id)
  end

  defp resource_exists?(%Resource{} = resource, state) do
    state.site_modules
    |> Enum.flat_map(&provider_resources(&1, snapshot(state)))
    |> Enum.any?(fn candidate ->
      candidate.site_id == resource.site_id and candidate.kind == resource.kind and
        candidate.id == resource.id
    end)
  end

  defp provider_resources(module, snapshot) do
    if function_exported?(module, :resources, 1) do
      module.resources(snapshot)
    else
      []
    end
  rescue
    _error -> []
  end

  defp process_action(state, verb) do
    suffix = ".process.#{verb}"

    state.site_modules
    |> Registry.actions()
    |> Enum.find(fn action -> String.ends_with?(action.id, suffix) end)
  end

  defp action_site_id(%Action{scope: {:site, site_id}}, _state), do: site_id

  defp action_site_id(%Action{provider: provider}, state) do
    state.site_modules
    |> Registry.sites()
    |> Enum.find_value(fn site ->
      if site.provider == provider do
        site.id
      end
    end)
  end

  defp input_key?(input, key) do
    Map.has_key?(input, key) or atom_key?(input, key)
  end

  defp logs_for_stream(state, stream_id) do
    logs_for_stream(state, stream_id, [])
  end

  defp logs_for_stream(state, stream_id, opts) do
    buffer = Map.get(state.logs, stream_id, LogRuntime.new_buffer(100))

    buffer
    |> LogRuntime.filter(
      level: Keyword.get(opts, :level),
      source_kind: Keyword.get(opts, :source_kind)
    )
    |> filter_log_fields(opts)
    |> filter_after_seq(Keyword.get(opts, :after_seq))
    |> tail(Keyword.get(opts, :tail))
  end

  defp resource_ref(%Resource{} = resource) do
    %{site_id: resource.site_id, kind: resource.kind, id: resource.id}
  end

  defp process_resource_ref(process_id),
    do: %{site_id: "execution_plane", kind: :process, id: process_id}

  defp env_summary(%{env: env, clear_env?: clear_env?}) when is_map(env) do
    %{keys: env |> Map.keys() |> Enum.sort(), count: map_size(env), clear_env?: clear_env?}
  end

  defp redact_command_preview(preview, %{env: env}) when is_binary(preview) and is_map(env) do
    Enum.reduce(env, preview, fn {_key, value}, acc ->
      value = to_string(value)

      if value == "" do
        acc
      else
        String.replace(acc, value, "[REDACTED]")
      end
    end)
  end

  defp stop_runtime_process(pid) when is_pid(pid), do: GenServer.stop(pid, :normal)

  defp stop_job(process_id, process) do
    job_id = "job-stop-#{process_id}"

    {:ok, job} =
      JobRuntime.new(%{
        id: job_id,
        kind: :process_stop,
        title: "Stop #{Map.get(process, :label, process_id)}",
        related_resources: [process_resource_ref(process_id)]
      })
      |> JobRuntime.transition(:succeeded)

    {job_id, job}
  end

  defp append_process_job(process, job_id) do
    Map.update(process, :job_ids, [job_id], fn job_ids ->
      job_ids
      |> List.wrap()
      |> Kernel.++([job_id])
      |> Enum.uniq()
    end)
  end

  defp context_resource(%{resource: %Resource{} = resource}), do: resource
  defp context_resource(_context), do: %{}

  defp fetch(attrs, key, default \\ nil)

  defp fetch(%{} = attrs, key, default) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))
  end

  defp fetch(_attrs, _key, default), do: default

  defp log_opts(payload) do
    [
      tail: fetch(payload, :tail),
      after_seq: fetch(payload, :after_seq),
      level: normalize_log_level(fetch(payload, :level)),
      source_kind: normalize_log_source_kind(fetch(payload, :source_kind)),
      process_id: fetch(payload, :process_id),
      job_id: fetch(payload, :job_id)
    ]
  end

  defp normalize_log_level(nil), do: nil
  defp normalize_log_level(value) when is_atom(value), do: value

  defp normalize_log_level(value) when is_binary(value),
    do: Map.get(@log_level_strings, value, value)

  defp normalize_log_level(value), do: value

  defp normalize_log_source_kind(nil), do: nil
  defp normalize_log_source_kind(value) when is_atom(value), do: value

  defp normalize_log_source_kind(value) when is_binary(value),
    do: Map.get(@log_source_kind_strings, value, value)

  defp normalize_log_source_kind(value), do: value

  defp filter_log_fields(events, opts) do
    process_id = Keyword.get(opts, :process_id)
    job_id = Keyword.get(opts, :job_id)

    Enum.filter(events, fn event ->
      match_log_field?(event, :process_id, process_id) and
        match_log_field?(event, :job_id, job_id)
    end)
  end

  defp match_log_field?(_event, _key, nil), do: true

  defp match_log_field?(event, key, expected) do
    Map.get(event.fields, key) == expected
  end

  defp filter_after_seq(events, nil), do: events

  defp filter_after_seq(events, after_seq) when is_integer(after_seq) do
    Enum.filter(events, fn event -> Map.get(event.fields, :seq, 0) > after_seq end)
  end

  defp filter_after_seq(events, after_seq) when is_binary(after_seq) do
    case Integer.parse(after_seq) do
      {seq, ""} -> filter_after_seq(events, seq)
      _other -> events
    end
  end

  defp filter_after_seq(events, _after_seq), do: events

  defp tail(events, nil), do: events

  defp tail(events, count) when is_integer(count) and count >= 0 do
    events
    |> Enum.take(-count)
  end

  defp tail(events, count) when is_binary(count) do
    case Integer.parse(count) do
      {parsed, ""} -> tail(events, parsed)
      _other -> events
    end
  end

  defp tail(events, _count), do: events

  defp append_log_event(state, %LogEvent{} = event) do
    seq = Map.get(state.stream_sequences, event.stream_id, 0) + 1
    event = %{event | fields: Map.put(event.fields, :seq, seq)}

    state
    |> update_in([:logs, event.stream_id], fn
      nil -> LogRuntime.new_buffer(100) |> LogRuntime.append(event)
      buffer -> LogRuntime.append(buffer, event)
    end)
    |> put_in([:stream_sequences, event.stream_id], seq)
  end

  defp append_job_event(state, job_id, event_kind, process_id, level) do
    append_log_event(
      state,
      LogEvent.new!(%{
        at: DateTime.utc_now(),
        level: level,
        source_kind: :job,
        source_id: job_id,
        stream_id: job_stream_id(job_id),
        message: "job #{event_kind}",
        fields: %{event_kind: event_kind, job_id: job_id, process_id: process_id}
      })
    )
  end

  defp maybe_append_job_event(state, job_id, event_kind, process_id, level) do
    if Map.has_key?(state.streams, job_stream_id(job_id)) do
      append_job_event(state, job_id, event_kind, process_id, level)
    else
      state
    end
  end

  defp ensure_stream(state, process_id) do
    stream_id = stream_id(process_id)

    state
    |> update_in([:logs, stream_id], fn
      nil -> LogRuntime.new_buffer(100)
      buffer -> buffer
    end)
    |> update_in([:streams, stream_id], fn
      nil ->
        StreamDescriptor.new!(%{
          id: stream_id,
          kind: :process_combined,
          subject: process_resource_ref(process_id),
          capabilities: [:tail]
        })

      descriptor ->
        descriptor
    end)
    |> update_in([:stream_sequences, stream_id], fn
      nil -> 0
      sequence -> sequence
    end)
  end

  defp ensure_job_stream(state, job_id, process_id) do
    stream_id = job_stream_id(job_id)

    state
    |> update_in([:logs, stream_id], fn
      nil -> LogRuntime.new_buffer(100)
      buffer -> buffer
    end)
    |> update_in([:streams, stream_id], fn
      nil ->
        StreamDescriptor.new!(%{
          id: stream_id,
          kind: :job_events,
          subject: %{site_id: "execution_plane", kind: :job, id: job_id, process_id: process_id},
          capabilities: [:tail]
        })

      descriptor ->
        descriptor
    end)
    |> update_in([:stream_sequences, stream_id], fn
      nil -> 0
      sequence -> sequence
    end)
  end

  defp streams_for_resource(state, %Resource{} = resource) do
    state.streams
    |> Map.values()
    |> Enum.filter(fn stream ->
      stream.subject[:site_id] == resource.site_id and stream.subject[:kind] == resource.kind and
        stream.subject[:id] == resource.id
    end)
    |> Enum.sort_by(& &1.id)
  end

  defp snapshot(state) do
    %{
      processes: state.processes |> Map.values() |> Enum.sort_by(& &1.id),
      jobs: state.jobs |> Map.values() |> Enum.sort_by(& &1.id),
      streams: state.streams |> Map.values() |> Enum.sort_by(& &1.id),
      operator_terminals: operator_terminal_snapshot(),
      runs: jido_runs_snapshot(),
      boundary_sessions: jido_boundary_sessions_snapshot(),
      attach_grants: jido_attach_grants_snapshot(),
      recovery_status: state.recovery_status
    }
  end

  defp recover_from_store(%{store_root: nil} = state), do: {:ok, state}

  defp recover_from_store(%{store_root: root} = state) do
    case Local.get_manifest(root, "daemon") do
      :error ->
        write_manifest(state)
        {:ok, %{state | recovery_status: initialized_recovery_status()}}

      {:ok, manifest} ->
        recover_from_manifest(state, manifest)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp recover_from_manifest(state, manifest) do
    snapshot_key = manifest["current_snapshot"] || @current_snapshot
    journal_key = manifest["current_journal"] || @current_journal

    with {:snapshot, {:ok, snapshot}} <-
           {:snapshot, Local.get_versioned_snapshot(state.store_root, "daemon", snapshot_key)},
         {:journal, {:ok, journal_events}} <-
           {:journal, read_recovery_journal(state, journal_key)} do
      state
      |> apply_persisted_snapshot(snapshot)
      |> apply_recovery_journal(journal_events)
      |> finalize_recovery()
      |> persist()
      |> then(&{:ok, &1})
    else
      {:snapshot, :error} -> {:ok, %{state | recovery_status: initialized_recovery_status()}}
      {:snapshot, {:error, reason}} -> {:error, reason}
      {:journal, {:error, reason}} -> {:error, reason}
    end
  end

  defp read_recovery_journal(%{store_root: root}, journal_key) do
    case Local.read_journal(root, "daemon", journal_key) do
      {:ok, events} -> {:ok, events}
      :error -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  defp apply_persisted_snapshot(state, snapshot) do
    %{
      state
      | processes: deserialize_processes(snapshot["processes"] || []),
        jobs: deserialize_jobs(snapshot["jobs"] || []),
        streams: deserialize_streams(snapshot["streams"] || []),
        stream_sequences: recovered_stream_sequences(snapshot["streams"] || [])
    }
  end

  defp apply_recovery_journal(state, events) do
    Enum.reduce(events, state, &apply_recovery_event/2)
  end

  defp apply_recovery_event(
         %{"kind" => "process_started", "payload" => %{"process" => process}},
         state
       ) do
    process = deserialize_process(process)
    put_in(state.processes[process.id], process)
  end

  defp apply_recovery_event(
         %{"kind" => "process_stopped", "payload" => %{"process_id" => id}},
         state
       ) do
    update_in(state.processes[id], fn
      nil -> nil
      process -> %{process | status: :stopped, status_reason: :operator_requested, pid: nil}
    end)
  end

  defp apply_recovery_event(_event, state), do: state

  defp finalize_recovery(state) do
    {processes, lost_processes, warnings} =
      state.processes
      |> Enum.reduce({%{}, [], []}, fn {process_id, process}, {processes, lost, warnings} ->
        {next_process, next_lost, next_warnings} = recover_process(process, lost, warnings)
        {Map.put(processes, process_id, next_process), next_lost, next_warnings}
      end)

    %{
      state
      | processes: processes,
        recovery_status: recovered_status(Enum.reverse(lost_processes), Enum.reverse(warnings))
    }
  end

  defp recover_process(%{status: status} = process, lost, warnings)
       when status in [:running, :starting, :stopping] do
    now = DateTime.utc_now()

    recovered_process = %{
      process
      | status: :lost,
        status_reason: :daemon_restarted_without_reconnect,
        last_seen_at: now,
        pid: nil
    }

    warning = "process #{process.id} marked lost after daemon restart"
    {recovered_process, [process.id | lost], [warning | warnings]}
  end

  defp recover_process(process, lost, warnings), do: {%{process | pid: nil}, lost, warnings}

  defp recovered_status([], []) do
    %{
      status: :ok,
      mode: :recovered,
      recovered?: true,
      recovered_at: DateTime.utc_now(),
      lost_processes: [],
      warnings: []
    }
  end

  defp recovered_status(lost_processes, warnings) do
    %{
      status: :degraded,
      mode: :recovered,
      recovered?: true,
      recovered_at: DateTime.utc_now(),
      lost_processes: lost_processes,
      warnings: warnings
    }
  end

  defp initialized_recovery_status do
    %{
      status: :ok,
      mode: :initialized,
      recovered?: false,
      warnings: []
    }
  end

  defp memory_only_recovery_status do
    %{
      status: :ok,
      mode: :memory_only,
      warnings: []
    }
  end

  defp write_manifest(%{store_root: nil}), do: :ok

  defp write_manifest(%{store_root: root, daemon_instance_id: daemon_instance_id}) do
    Local.put_manifest(root, "daemon", %{
      "schema_version" => @schema_version,
      "store_created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "last_written_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "daemon_instance_id" => daemon_instance_id,
      "current_snapshot" => @current_snapshot,
      "current_journal" => @current_journal,
      "retention_policy" => %{"streams" => "memory_only"},
      "migration_history" => []
    })
  end

  defp persist(%{store_root: nil} = state), do: state

  defp persist(%{store_root: root} = state) do
    serialized_snapshot = serialize_snapshot(snapshot(state), state)

    Local.put_snapshot(root, "daemon", "local_snapshot", serialized_snapshot)
    Local.put_versioned_snapshot(root, "daemon", @current_snapshot, serialized_snapshot)
    write_manifest(state)

    state
  end

  defp serialize_snapshot(snapshot, state) do
    %{
      "schema_version" => @schema_version,
      "written_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "daemon_instance_id" => state.daemon_instance_id,
      "processes" => Enum.map(snapshot.processes, &serialize_process/1),
      "jobs" => Enum.map(snapshot.jobs, &serialize_job/1),
      "streams" => Enum.map(snapshot.streams, &serialize_stream/1),
      "operator_terminals" => Enum.map(snapshot.operator_terminals, &serialize_generic_map/1),
      "runs" => Enum.map(snapshot.runs, &serialize_generic_map/1),
      "boundary_sessions" => Enum.map(snapshot.boundary_sessions, &serialize_generic_map/1),
      "attach_grants" => Enum.map(snapshot.attach_grants, &serialize_generic_map/1),
      "recovery_status" => stringify_map(snapshot.recovery_status)
    }
  end

  defp serialize_process(process) do
    process
    |> Map.take([
      :id,
      :label,
      :status,
      :status_reason,
      :exit_status,
      :started_at,
      :stopped_at,
      :last_seen_at,
      :command,
      :command_preview,
      :args,
      :shell?,
      :cwd,
      :env_summary,
      :execution_surface,
      :sandbox,
      :job_ids,
      :stream_ids
    ])
    |> Enum.into(%{}, fn {key, value} -> {Atom.to_string(key), stringify_value(value)} end)
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

  defp serialize_stream(stream) do
    %{
      "id" => stream.id,
      "kind" => Atom.to_string(stream.kind),
      "subject" => stringify_value(stream.subject),
      "retention" => Atom.to_string(stream.retention),
      "capabilities" => Enum.map(stream.capabilities, &Atom.to_string/1)
    }
  end

  defp deserialize_processes(processes) when is_list(processes) do
    processes
    |> Enum.map(&deserialize_process/1)
    |> Map.new(&{&1.id, &1})
  end

  defp deserialize_process(%{} = process) do
    process_id = string_field(process, "id")

    %{
      id: process_id,
      label: string_field(process, "label") || process_id,
      status: atom_field(process, "status", :unknown),
      status_reason: atom_field(process, "status_reason", :unknown),
      exit_status: process["exit_status"],
      started_at: datetime_field(process, "started_at"),
      stopped_at: datetime_field(process, "stopped_at"),
      last_seen_at: datetime_field(process, "last_seen_at"),
      command: string_field(process, "command"),
      command_preview: string_field(process, "command_preview"),
      args: List.wrap(process["args"]),
      shell?: boolean_field(process, "shell?", true),
      cwd: string_field(process, "cwd"),
      env_summary: process["env_summary"] || %{},
      execution_surface: process["execution_surface"] || %{},
      sandbox: process["sandbox"] || %{},
      pid: nil,
      job_ids: List.wrap(process["job_ids"]),
      stream_ids: List.wrap(process["stream_ids"])
    }
  end

  defp deserialize_jobs(jobs) when is_list(jobs) do
    jobs
    |> Enum.map(&deserialize_job/1)
    |> Map.new(&{&1.id, &1})
  end

  defp deserialize_job(%{} = job) do
    Job.new!(%{
      id: string_field(job, "id"),
      kind: atom_field(job, "kind", :unknown),
      title: string_field(job, "title") || string_field(job, "id"),
      status: atom_field(job, "status", :queued),
      progress: atomized_progress(job["progress"] || %{}),
      started_at: datetime_field(job, "started_at"),
      finished_at: datetime_field(job, "finished_at"),
      related_resources: List.wrap(job["related_resources"])
    })
  end

  defp deserialize_streams(streams) when is_list(streams) do
    streams
    |> Enum.map(&deserialize_stream/1)
    |> Map.new(&{&1.id, &1})
  end

  defp deserialize_stream(%{} = stream) do
    StreamDescriptor.new!(%{
      id: string_field(stream, "id"),
      kind: atom_field(stream, "kind", :unknown),
      subject: atomized_subject(stream["subject"]),
      retention: atom_field(stream, "retention", :bounded),
      capabilities: stream |> Map.get("capabilities", []) |> Enum.map(&atomish/1)
    })
  end

  defp recovered_stream_sequences(streams) when is_list(streams) do
    streams
    |> Enum.map(fn stream -> {stream["id"], 0} end)
    |> Enum.reject(fn {stream_id, _sequence} -> is_nil(stream_id) end)
    |> Map.new()
  end

  defp string_field(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> atom_value_for_string_key(map, key)
    end
  end

  defp atom_field(map, key, default) do
    case string_field(map, key) do
      nil -> default
      value -> atomish(value)
    end
  end

  defp boolean_field(map, key, default) do
    case string_field(map, key) do
      value when is_boolean(value) -> value
      nil -> default
      _other -> default
    end
  end

  defp datetime_field(map, key) do
    case string_field(map, key) do
      %DateTime{} = datetime ->
        datetime

      value when is_binary(value) ->
        case DateTime.from_iso8601(value) do
          {:ok, datetime, _offset} -> datetime
          _other -> nil
        end

      _other ->
        nil
    end
  end

  defp atomized_progress(%{} = progress) do
    %{
      current: progress["current"] || progress[:current] || 0,
      total: progress["total"] || progress[:total] || 0
    }
  end

  defp atomized_subject(%{} = subject) do
    subject
    |> Enum.map(fn {key, value} -> {atomish(key), atomized_subject_value(key, value)} end)
    |> Map.new()
  end

  defp atomized_subject(subject), do: subject

  defp atomized_subject_value(key, value) when key in ["kind", :kind], do: atomish(value)
  defp atomized_subject_value(_key, value), do: value

  defp atomish(value) when is_atom(value), do: value

  defp atomish(value) when is_binary(value) do
    Map.get(@atomish_strings, value, :unknown)
  end

  defp atomish(_value), do: :unknown

  defp atom_key?(map, key) when is_map(map) and is_binary(key) do
    Enum.any?(map, fn
      {atom_key, _value} when is_atom(atom_key) -> Atom.to_string(atom_key) == key
      _entry -> false
    end)
  end

  defp atom_key?(_map, _key), do: false

  defp atom_value_for_string_key(map, key) when is_map(map) and is_binary(key) do
    Enum.find_value(map, fn
      {atom_key, value} when is_atom(atom_key) ->
        if Atom.to_string(atom_key) == key, do: value

      _entry ->
        nil
    end)
  end

  defp atom_value_for_string_key(_map, _key), do: nil

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
    command_prefix = sandbox.policy |> Map.get(:command_prefix, []) |> List.wrap()

    %{
      "mode" => Atom.to_string(sandbox.mode),
      "enforced" => sandbox_enforced?(sandbox, command_prefix),
      "enforcement_surface" => sandbox_enforcement_surface(sandbox, command_prefix),
      "policy" => %{
        "keys" => sandbox.policy |> Map.keys() |> Enum.map(&Atom.to_string/1) |> Enum.sort(),
        "writable_roots" => Map.get(sandbox.policy, :writable_roots),
        "network_access" =>
          case Map.get(sandbox.policy, :network_access) do
            nil -> nil
            value when is_atom(value) -> Atom.to_string(value)
            value -> value
          end,
        "has_command_prefix" => command_prefix != []
      }
    }
  end

  defp sandbox_enforced?(%{mode: mode}, _command_prefix)
       when mode in [:inherit, :danger_full_access],
       do: true

  defp sandbox_enforced?(_sandbox, command_prefix), do: command_prefix != []

  defp sandbox_enforcement_surface(%{mode: mode}, _command_prefix)
       when mode in [:inherit, :danger_full_access],
       do: "native"

  defp sandbox_enforcement_surface(_sandbox, []), do: "unsupported"
  defp sandbox_enforcement_surface(_sandbox, _command_prefix), do: "command_prefix"

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

  defp stringify_value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp stringify_value(value) when is_boolean(value), do: value
  defp stringify_value(nil), do: nil
  defp stringify_value(value) when is_map(value), do: stringify_map(value)
  defp stringify_value(value) when is_list(value), do: Enum.map(value, &stringify_value/1)
  defp stringify_value(value) when is_atom(value), do: Atom.to_string(value)
  defp stringify_value(value), do: value

  defp stringify_atomish(nil), do: nil
  defp stringify_atomish(value) when is_atom(value), do: Atom.to_string(value)
  defp stringify_atomish(value), do: to_string(value)

  defp stream_id(process_id), do: "logs/#{process_id}"
  defp job_stream_id(job_id), do: "jobs/#{job_id}"
end
