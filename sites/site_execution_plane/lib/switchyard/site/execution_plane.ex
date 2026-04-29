defmodule Switchyard.Site.ExecutionPlane do
  @moduledoc """
  Execution Plane substrate/admin site.
  """

  @behaviour Switchyard.Contracts.SiteProvider

  alias Switchyard.Contracts.{
    Action,
    AppDescriptor,
    Resource,
    ResourceDetail,
    SiteDescriptor
  }

  @site_id "execution_plane"

  @impl true
  def site_definition do
    SiteDescriptor.new!(%{
      id: @site_id,
      title: "Execution Plane",
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
        resource_kinds: [:process],
        route_kind: :list_detail
      }),
      AppDescriptor.new!(%{
        id: "execution_plane.operator_terminals",
        site_id: @site_id,
        title: "Operator Terminals",
        provider: __MODULE__,
        resource_kinds: [:operator_terminal],
        route_kind: :list_detail
      }),
      AppDescriptor.new!(%{
        id: "execution_plane.jobs",
        site_id: @site_id,
        title: "Jobs",
        provider: __MODULE__,
        resource_kinds: [:job],
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
    process_resources(snapshot) ++
      operator_terminal_resources(snapshot) ++ job_resources(snapshot)
  end

  @impl true
  def execute_action(action_id, _input, _context) do
    {:error, {:daemon_owned_action, action_id}}
  end

  @impl true
  def detail(%Resource{kind: :process} = resource, snapshot) do
    process =
      snapshot
      |> Map.get(:processes, [])
      |> Enum.find(fn candidate -> candidate.id == resource.id end)

    ResourceDetail.new!(%{
      resource: resource,
      sections: [
        %{
          title: "Execution Plane Process",
          lines: [
            "command: #{process.command_preview || process.command}",
            "status: #{process.status}",
            "status_reason: #{Map.get(process, :status_reason, "unknown")}",
            "exit_status: #{Map.get(process, :exit_status, "none")}",
            "jobs: #{Enum.join(Map.get(process, :job_ids, []), ", ")}",
            "streams: #{Enum.join(Map.get(process, :stream_ids, []), ", ")}",
            "surface: #{surface_kind(process)}",
            "target: #{surface_target(process)}",
            "sandbox: #{sandbox_mode(process)}"
          ]
        }
      ],
      recommended_actions: ["Stop process"]
    })
  end

  def detail(%Resource{kind: :operator_terminal} = resource, snapshot) do
    operator_terminal =
      snapshot
      |> Map.get(:operator_terminals, [])
      |> Enum.find(fn candidate -> candidate.id == resource.id end)

    ResourceDetail.new!(%{
      resource: resource,
      sections: [
        %{
          title: "Operator Terminal",
          lines: [
            "surface: #{operator_terminal.surface_kind}",
            "status: #{operator_terminal.status}",
            "boundary_class: #{operator_terminal.boundary_class || "none"}"
          ]
        }
      ],
      recommended_actions: []
    })
  end

  def detail(%Resource{kind: :job} = resource, snapshot) do
    job =
      snapshot
      |> Map.get(:jobs, [])
      |> Enum.find(fn candidate -> candidate.id == resource.id end)

    ResourceDetail.new!(%{
      resource: resource,
      sections: [
        %{
          title: "Job",
          lines: [
            "status: #{job.status}",
            "progress: #{job.progress.current}/#{job.progress.total}"
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
        id: process.id,
        title: process.label,
        subtitle: to_string(process.status),
        status: status_atom(process.status),
        capabilities: [:inspect, :stop],
        summary: process.command_preview || process.command
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
        id: operator_terminal.id,
        title: operator_terminal.id,
        subtitle: operator_terminal.surface_kind,
        status: String.to_atom(operator_terminal.status),
        capabilities: [:inspect],
        summary: operator_terminal.boundary_class || operator_terminal.surface_ref || "operator"
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
        id: job.id,
        title: job.title,
        subtitle: Atom.to_string(job.status),
        status: job.status,
        capabilities: [:inspect],
        summary: "#{job.progress.current}/#{job.progress.total}"
      })
    end)
  end

  defp surface_kind(process) do
    process
    |> Map.get(:execution_surface, %{})
    |> Map.get("surface_kind", "local_subprocess")
  end

  defp surface_target(process) do
    process
    |> Map.get(:execution_surface, %{})
    |> Map.get("target_id", "local")
  end

  defp sandbox_mode(process) do
    process
    |> Map.get(:sandbox, %{})
    |> Map.get("mode", "inherit")
  end

  defp status_atom(status) when is_atom(status), do: status
  defp status_atom(status) when is_binary(status), do: String.to_atom(status)
end
