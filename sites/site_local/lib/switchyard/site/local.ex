defmodule Switchyard.Site.Local do
  @moduledoc """
  Built-in local operations site.
  """

  @behaviour Switchyard.Contracts.SiteProvider

  alias Switchyard.Contracts.{
    Action,
    AppDescriptor,
    Resource,
    ResourceDetail,
    SiteDescriptor
  }

  @site_id "local"

  @impl true
  def site_definition do
    SiteDescriptor.new!(%{
      id: @site_id,
      title: "Local",
      provider: __MODULE__,
      kind: :local,
      capabilities: [:apps, :actions, :resources]
    })
  end

  @impl true
  def apps do
    [
      AppDescriptor.new!(%{
        id: "local.processes",
        site_id: @site_id,
        title: "Processes",
        provider: __MODULE__,
        resource_kinds: [:process],
        route_kind: :list_detail
      }),
      AppDescriptor.new!(%{
        id: "local.jobs",
        site_id: @site_id,
        title: "Jobs",
        provider: __MODULE__,
        resource_kinds: [:job],
        route_kind: :list_detail
      }),
      AppDescriptor.new!(%{
        id: "local.logs",
        site_id: @site_id,
        title: "Logs",
        provider: __MODULE__,
        resource_kinds: [:log_stream],
        route_kind: :list_detail
      })
    ]
  end

  @impl true
  def actions do
    [
      Action.new!(%{
        id: "local.process.start",
        title: "Start process",
        scope: {:site, @site_id},
        provider: __MODULE__
      }),
      Action.new!(%{
        id: "local.process.stop",
        title: "Stop process",
        scope: {:resource, :process},
        provider: __MODULE__,
        confirmation: :if_destructive
      })
    ]
  end

  @impl true
  def resources(snapshot) when is_map(snapshot) do
    processes =
      snapshot
      |> Map.get(:processes, [])
      |> Enum.map(&process_resource/1)

    jobs =
      snapshot
      |> Map.get(:jobs, [])
      |> Enum.map(&job_resource/1)

    processes ++ jobs
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
          title: "Process",
          lines: [
            "command: #{process.command_preview || process.command}",
            "status: #{process.status}",
            "surface: #{surface_kind(process)}",
            "target: #{surface_target(process)}",
            "sandbox: #{sandbox_mode(process)}"
          ]
        }
      ],
      recommended_actions: ["Stop process"]
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

  defp process_resource(process) do
    Resource.new!(%{
      site_id: @site_id,
      kind: :process,
      id: process.id,
      title: process.label,
      subtitle: process.status,
      status: String.to_atom(process.status),
      capabilities: [:inspect, :stop],
      summary: process.command_preview || process.command
    })
  end

  defp job_resource(job) do
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
end
