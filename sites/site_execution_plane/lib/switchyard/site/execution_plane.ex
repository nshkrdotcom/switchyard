defmodule Switchyard.Site.ExecutionPlane do
  @moduledoc """
  Execution Plane substrate/admin site.
  """

  @behaviour Switchyard.Contracts.SiteProvider
  @behaviour Switchyard.Contracts.SearchProvider

  alias Switchyard.Contracts.{
    Action,
    AppDescriptor,
    Resource,
    ResourceDetail,
    SearchResult,
    SiteDescriptor
  }

  @site_id "execution_plane"
  @site_atom :execution_plane
  @site_title "Execution Plane"
  @state_kind :site_state
  @status_atoms %{
    "accepted" => :accepted,
    "available" => :available,
    "cancelled" => :cancelled,
    "canceled" => :canceled,
    "completed" => :completed,
    "degraded" => :degraded,
    "empty" => :empty,
    "error" => :error,
    "failed" => :failed,
    "issued" => :issued,
    "lost" => :lost,
    "pending" => :pending,
    "queued" => :queued,
    "running" => :running,
    "stopped" => :stopped,
    "succeeded" => :succeeded,
    "terminal" => :terminal,
    "unavailable" => :unavailable
  }

  @impl true
  def site_definition do
    SiteDescriptor.new!(%{
      id: @site_id,
      title: @site_title,
      provider: __MODULE__,
      kind: :service,
      capabilities: [:apps, :actions, :resources]
    })
  end

  @impl true
  def apps do
    [
      AppDescriptor.new!(%{
        id: "execution_plane.processes",
        site_id: @site_id,
        title: "Processes",
        provider: __MODULE__,
        resource_kinds: [:process, @state_kind],
        route_kind: :list_detail
      }),
      AppDescriptor.new!(%{
        id: "execution_plane.operator_terminals",
        site_id: @site_id,
        title: "Operator Terminals",
        provider: __MODULE__,
        resource_kinds: [:operator_terminal, @state_kind],
        route_kind: :list_detail
      }),
      AppDescriptor.new!(%{
        id: "execution_plane.jobs",
        site_id: @site_id,
        title: "Jobs",
        provider: __MODULE__,
        resource_kinds: [:job, @state_kind],
        route_kind: :list_detail
      }),
      AppDescriptor.new!(%{
        id: "execution_plane.streams",
        site_id: @site_id,
        title: "Streams",
        provider: __MODULE__,
        resource_kinds: [:stream, @state_kind],
        route_kind: :list_detail
      })
    ]
  end

  @impl true
  def actions do
    [
      Action.new!(%{
        id: "execution_plane.process.start",
        title: "Start process",
        scope: {:site, @site_id},
        provider: __MODULE__,
        input_schema: %{
          "type" => "object",
          "required" => ["command"],
          "properties" => %{
            "command" => %{"type" => "string", "description" => "Command to run"},
            "cwd" => %{"type" => "string", "description" => "Working directory"},
            "shell?" => %{"type" => "boolean", "default" => true}
          }
        }
      }),
      Action.new!(%{
        id: "execution_plane.process.stop",
        title: "Stop process",
        scope: {:resource, :process},
        provider: __MODULE__,
        confirmation: :if_destructive
      }),
      Action.new!(%{
        id: "execution_plane.process.force_stop",
        title: "Force stop process",
        scope: {:resource, :process},
        provider: __MODULE__,
        confirmation: :if_destructive
      }),
      Action.new!(%{
        id: "execution_plane.process.signal",
        title: "Signal process",
        scope: {:resource, :process},
        provider: __MODULE__
      }),
      Action.new!(%{
        id: "execution_plane.process.restart",
        title: "Restart process",
        scope: {:resource, :process},
        provider: __MODULE__,
        confirmation: :if_destructive
      })
    ]
  end

  @impl true
  def resources(snapshot) when is_map(snapshot) do
    mapped_resources =
      process_resources(snapshot) ++
        operator_terminal_resources(snapshot) ++
        job_resources(snapshot) ++ stream_resources(snapshot)

    state_resources(snapshot, mapped_resources) ++ mapped_resources
  end

  @impl true
  def execute_action(action_id, _input, _context) do
    {:error, {:daemon_owned_action, action_id}}
  end

  @impl true
  def search(query, snapshot) when is_binary(query) and is_map(snapshot) do
    normalized_query = normalize_query(query)

    if normalized_query == "" do
      []
    else
      snapshot
      |> resources()
      |> Enum.flat_map(&search_match(&1, normalized_query))
      |> Enum.sort_by(& &1.score, :desc)
    end
  end

  @impl true
  def detail(%Resource{kind: :process} = resource, snapshot) do
    snapshot
    |> Map.get(:processes, [])
    |> Enum.find(fn candidate -> field(candidate, :id) == resource.id end)
    |> case do
      nil ->
        missing_detail(resource)

      process ->
        ResourceDetail.new!(%{
          resource: resource,
          sections: [
            %{
              title: "Execution Plane Process",
              lines: [
                "command: #{field(process, :command_preview) || field(process, :command)}",
                "status: #{field(process, :status)}",
                "status_reason: #{field(process, :status_reason) || "unknown"}",
                "exit_status: #{field(process, :exit_status) || "none"}",
                "jobs: #{join_values(field(process, :job_ids, []))}",
                "streams: #{join_values(field(process, :stream_ids, []))}",
                "actions: execution_plane.process.stop, execution_plane.process.restart, execution_plane.process.signal",
                "surface: #{surface_kind(process)}",
                "target: #{surface_target(process)}",
                "sandbox: #{sandbox_mode(process)}"
              ]
            }
          ],
          recommended_actions: ["Stop process"]
        })
    end
  end

  def detail(%Resource{kind: :operator_terminal} = resource, snapshot) do
    snapshot
    |> Map.get(:operator_terminals, [])
    |> Enum.find(fn candidate -> field(candidate, :id) == resource.id end)
    |> case do
      nil ->
        missing_detail(resource)

      operator_terminal ->
        ResourceDetail.new!(%{
          resource: resource,
          sections: [
            %{
              title: "Operator Terminal",
              lines: [
                "purpose: operator UI transport",
                "managed_process_attach: no",
                "surface: #{field(operator_terminal, :surface_kind)}",
                "status: #{field(operator_terminal, :status)}",
                "boundary_class: #{field(operator_terminal, :boundary_class) || "none"}",
                "surface_ref: #{field(operator_terminal, :surface_ref) || "none"}"
              ]
            }
          ],
          recommended_actions: []
        })
    end
  end

  def detail(%Resource{kind: :job} = resource, snapshot) do
    snapshot
    |> Map.get(:jobs, [])
    |> Enum.find(fn candidate -> field(candidate, :id) == resource.id end)
    |> case do
      nil ->
        missing_detail(resource)

      job ->
        ResourceDetail.new!(%{
          resource: resource,
          sections: [
            %{
              title: "Job",
              lines: [
                "status: #{field(job, :status)}",
                "progress: #{progress_line(job)}",
                "processes: #{join_values(field(job, :process_ids, []))}",
                "streams: #{join_values(field(job, :stream_ids, []))}"
              ]
            }
          ],
          recommended_actions: []
        })
    end
  end

  def detail(%Resource{kind: :stream} = resource, snapshot) do
    snapshot
    |> Map.get(:streams, [])
    |> Enum.find(fn candidate -> field(candidate, :id) == resource.id end)
    |> case do
      nil ->
        missing_detail(resource)

      stream ->
        ResourceDetail.new!(%{
          resource: resource,
          sections: [
            %{
              title: "Stream",
              lines: [
                "kind: #{field(stream, :kind)}",
                "subject: #{format_subject(field(stream, :subject))}",
                "retention: #{field(stream, :retention) || "unknown"}",
                "capabilities: #{join_values(field(stream, :capabilities, []))}"
              ]
            }
          ],
          recommended_actions: []
        })
    end
  end

  def detail(%Resource{kind: @state_kind} = resource, _snapshot) do
    ResourceDetail.new!(%{
      resource: resource,
      sections: [
        %{
          title: "Site State",
          lines: [
            "status: #{resource.status}",
            "message: #{resource.summary || "none"}"
          ]
        }
      ],
      recommended_actions: []
    })
  end

  defp process_resources(snapshot) do
    snapshot
    |> Map.get(:processes, [])
    |> Enum.map(fn process ->
      Resource.new!(%{
        site_id: @site_id,
        kind: :process,
        id: field(process, :id),
        title: field(process, :label) || field(process, :id),
        subtitle: to_string(field(process, :status)),
        status: status_atom(field(process, :status)),
        capabilities: [:inspect, :stop],
        summary: field(process, :command_preview) || field(process, :command),
        ext: %{
          job_ids: field(process, :job_ids, []),
          stream_ids: field(process, :stream_ids, [])
        }
      })
    end)
  end

  defp operator_terminal_resources(snapshot) do
    snapshot
    |> Map.get(:operator_terminals, [])
    |> Enum.map(fn operator_terminal ->
      Resource.new!(%{
        site_id: @site_id,
        kind: :operator_terminal,
        id: field(operator_terminal, :id),
        title: field(operator_terminal, :id),
        subtitle: field(operator_terminal, :surface_kind),
        status: status_atom(field(operator_terminal, :status)),
        capabilities: [:inspect],
        tags: [:operator_ui_transport],
        summary:
          field(operator_terminal, :boundary_class) || field(operator_terminal, :surface_ref) ||
            "operator",
        ext: %{managed_process_attach: false}
      })
    end)
  end

  defp job_resources(snapshot) do
    snapshot
    |> Map.get(:jobs, [])
    |> Enum.map(fn job ->
      Resource.new!(%{
        site_id: @site_id,
        kind: :job,
        id: field(job, :id),
        title: field(job, :title) || field(job, :id),
        subtitle: to_string(field(job, :status)),
        status: status_atom(field(job, :status)),
        capabilities: [:inspect],
        summary: progress_line(job),
        ext: %{
          process_ids: field(job, :process_ids, []),
          stream_ids: field(job, :stream_ids, [])
        }
      })
    end)
  end

  defp stream_resources(snapshot) do
    snapshot
    |> Map.get(:streams, [])
    |> Enum.map(fn stream ->
      Resource.new!(%{
        site_id: @site_id,
        kind: :stream,
        id: field(stream, :id),
        title: field(stream, :id),
        subtitle: to_string(field(stream, :kind)),
        status: :available,
        capabilities: [:inspect] ++ List.wrap(field(stream, :capabilities, [])),
        summary: format_subject(field(stream, :subject)),
        ext: %{
          subject: field(stream, :subject),
          retention: field(stream, :retention),
          capabilities: field(stream, :capabilities, [])
        }
      })
    end)
  end

  defp state_resources(snapshot, mapped_resources) do
    case site_state(snapshot) do
      nil when mapped_resources == [] ->
        [state_resource(:empty, "No Execution Plane resources in snapshot")]

      nil ->
        []

      %{status: status} = state ->
        [
          state_resource(
            status_atom(status),
            field(state, :message) || "Execution Plane #{status}"
          )
        ]
    end
  end

  defp state_resource(status, message) do
    Resource.new!(%{
      site_id: @site_id,
      kind: @state_kind,
      id: "#{@site_id}.state.#{status}",
      title: "#{@site_title} #{status}",
      subtitle: to_string(status),
      status: status,
      tags: [:site_state, status],
      capabilities: [:inspect],
      summary: message
    })
  end

  defp site_state(snapshot) do
    snapshot
    |> Map.get(:site_states, %{})
    |> case do
      states when is_map(states) ->
        Map.get(states, @site_id) || Map.get(states, @site_atom)

      _other ->
        nil
    end
    |> case do
      nil -> Map.get(snapshot, :site_state)
      state -> state
    end
  end

  defp search_match(%Resource{} = resource, query) do
    haystack =
      [resource.id, resource.title, resource.subtitle, resource.summary, resource.kind]
      |> Enum.map_join(" ", &to_string/1)
      |> String.downcase()

    cond do
      String.downcase(resource.id) == query ->
        [search_result(resource, 1.0)]

      String.contains?(haystack, query) ->
        [search_result(resource, 0.75)]

      true ->
        []
    end
  end

  defp search_result(%Resource{} = resource, score) do
    SearchResult.new!(%{
      id: "#{resource.site_id}:#{resource.kind}:#{resource.id}",
      kind: resource.kind,
      title: resource.title,
      subtitle: resource.summary || resource.subtitle,
      action: {:open_resource, {resource.site_id, resource.kind, resource.id}},
      score: score
    })
  end

  defp missing_detail(%Resource{} = resource) do
    ResourceDetail.new!(%{
      resource: resource,
      sections: [%{title: "Missing Resource", lines: ["resource not present in snapshot"]}],
      recommended_actions: []
    })
  end

  defp progress_line(job) do
    progress = field(job, :progress, %{})
    "#{field(progress, :current, 0)}/#{field(progress, :total, 0)}"
  end

  defp surface_kind(process) do
    process
    |> field(:execution_surface, %{})
    |> field("surface_kind", "local_subprocess")
  end

  defp surface_target(process) do
    process
    |> field(:execution_surface, %{})
    |> field("target_id", "local")
  end

  defp sandbox_mode(process) do
    process
    |> field(:sandbox, %{})
    |> field("mode", "inherit")
  end

  defp format_subject({:process, id}), do: "process #{id}"
  defp format_subject({:job, id}), do: "job #{id}"
  defp format_subject(subject) when is_binary(subject), do: subject
  defp format_subject(subject), do: inspect(redact(subject))

  defp join_values([]), do: "none"

  defp join_values(values) when is_list(values) do
    Enum.map_join(values, ", ", &to_string/1)
  end

  defp join_values(value), do: to_string(value)

  defp normalize_query(query) do
    query
    |> String.trim()
    |> String.downcase()
  end

  defp status_atom(status) when is_atom(status), do: status

  defp status_atom(status) when is_binary(status) do
    status
    |> String.downcase()
    |> String.replace("-", "_")
    |> then(&Map.get(@status_atoms, &1, :unknown))
  end

  defp status_atom(_status), do: :unknown

  defp field(map, key, default \\ nil)

  defp field(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp field(_map, _key, default), do: default

  defp redact(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      if secret_key?(key), do: {key, "[redacted]"}, else: {key, redact(value)}
    end)
  end

  defp redact(values) when is_list(values), do: Enum.map(values, &redact/1)
  defp redact({left, right}), do: {redact(left), redact(right)}
  defp redact(value), do: value

  defp secret_key?(key) do
    key
    |> to_string()
    |> String.downcase()
    |> then(&String.contains?(&1, ["secret", "token", "password", "credential", "api_key"]))
  end
end
