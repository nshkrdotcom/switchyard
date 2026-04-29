defmodule Switchyard.Site.Jido do
  @moduledoc """
  Durable Jido operator site.
  """

  @behaviour Switchyard.Contracts.SiteProvider

  alias Switchyard.Contracts.{
    Action,
    ActionResult,
    AppDescriptor,
    Resource,
    ResourceDetail,
    SiteDescriptor
  }

  @site_id "jido"

  @impl true
  def site_definition do
    SiteDescriptor.new!(%{
      id: @site_id,
      title: "Jido",
      provider: __MODULE__,
      kind: :service,
      capabilities: [:apps, :actions, :resources]
    })
  end

  @impl true
  def apps do
    [
      AppDescriptor.new!(%{
        id: "jido.runs",
        site_id: @site_id,
        title: "Runs",
        provider: __MODULE__,
        resource_kinds: [:run],
        route_kind: :list_detail
      }),
      AppDescriptor.new!(%{
        id: "jido.boundary_sessions",
        site_id: @site_id,
        title: "Boundary Sessions",
        provider: __MODULE__,
        resource_kinds: [:boundary_session],
        route_kind: :list_detail
      }),
      AppDescriptor.new!(%{
        id: "jido.attach_grants",
        site_id: @site_id,
        title: "Attach Grants",
        provider: __MODULE__,
        resource_kinds: [:attach_grant],
        route_kind: :list_detail
      })
    ]
  end

  @impl true
  def actions do
    [
      Action.new!(%{
        id: "jido.review.refresh",
        title: "Refresh durable state",
        scope: {:site, @site_id},
        provider: __MODULE__
      })
    ]
  end

  @impl true
  def resources(snapshot) when is_map(snapshot) do
    run_resources(snapshot) ++
      boundary_session_resources(snapshot) ++ attach_grant_resources(snapshot)
  end

  @impl true
  def execute_action("jido.review.refresh", input, _context) do
    {:ok,
     ActionResult.new!(%{
       status: :succeeded,
       message: "durable state refreshed",
       output: %{input: input}
     })}
  end

  @impl true
  def detail(%Resource{kind: :run} = resource, snapshot) do
    run =
      snapshot
      |> Map.get(:runs, [])
      |> Enum.find(fn candidate -> candidate.id == resource.id end)

    ResourceDetail.new!(%{
      resource: resource,
      sections: [
        %{
          title: "Run",
          lines: [
            "status: #{run.status}",
            "capability: #{run.capability_id}",
            "runtime_class: #{run.runtime_class}",
            "target: #{run.target_id || "none"}",
            "tenant: #{run.tenant_id || "unknown"}"
          ]
        }
      ],
      recommended_actions: []
    })
  end

  def detail(%Resource{kind: :boundary_session} = resource, snapshot) do
    session =
      snapshot
      |> Map.get(:boundary_sessions, [])
      |> Enum.find(fn candidate -> candidate.id == resource.id end)

    ResourceDetail.new!(%{
      resource: resource,
      sections: [
        %{
          title: "Boundary Session",
          lines: [
            "status: #{session.status}",
            "route: #{session.route_id || "none"}",
            "target: #{session.target_id || "none"}",
            "attach_grant: #{session.attach_grant_id || "none"}"
          ]
        }
      ],
      recommended_actions: []
    })
  end

  def detail(%Resource{kind: :attach_grant} = resource, snapshot) do
    attach_grant =
      snapshot
      |> Map.get(:attach_grants, [])
      |> Enum.find(fn candidate -> candidate.id == resource.id end)

    ResourceDetail.new!(%{
      resource: resource,
      sections: [
        %{
          title: "Attach Grant",
          lines: [
            "status: #{attach_grant.status}",
            "boundary_session: #{attach_grant.boundary_session_id}",
            "route: #{attach_grant.route_id || "none"}",
            "subject: #{attach_grant.subject_id || "none"}"
          ]
        }
      ],
      recommended_actions: []
    })
  end

  defp run_resources(snapshot) do
    snapshot
    |> Map.get(:runs, [])
    |> Enum.map(fn run ->
      Resource.new!(%{
        site_id: @site_id,
        kind: :run,
        id: run.id,
        title: run.id,
        subtitle: run.status,
        status: String.to_atom(run.status),
        capabilities: [:inspect],
        summary: run.capability_id
      })
    end)
  end

  defp boundary_session_resources(snapshot) do
    snapshot
    |> Map.get(:boundary_sessions, [])
    |> Enum.map(fn session ->
      Resource.new!(%{
        site_id: @site_id,
        kind: :boundary_session,
        id: session.id,
        title: session.id,
        subtitle: session.status,
        status: String.to_atom(session.status),
        capabilities: [:inspect],
        summary: session.route_id || session.target_id || "boundary"
      })
    end)
  end

  defp attach_grant_resources(snapshot) do
    snapshot
    |> Map.get(:attach_grants, [])
    |> Enum.map(fn attach_grant ->
      Resource.new!(%{
        site_id: @site_id,
        kind: :attach_grant,
        id: attach_grant.id,
        title: attach_grant.id,
        subtitle: attach_grant.status,
        status: String.to_atom(attach_grant.status),
        capabilities: [:inspect],
        summary: attach_grant.boundary_session_id
      })
    end)
  end
end
