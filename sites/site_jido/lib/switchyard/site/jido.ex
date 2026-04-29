defmodule Switchyard.Site.Jido do
  @moduledoc """
  Durable Jido operator site.
  """

  @behaviour Switchyard.Contracts.SiteProvider
  @behaviour Switchyard.Contracts.SearchProvider

  alias Switchyard.Contracts.{
    Action,
    ActionResult,
    AppDescriptor,
    Resource,
    ResourceDetail,
    SearchResult,
    SiteDescriptor
  }

  @site_id "jido"
  @site_title "Jido"
  @state_kind :site_state
  @status_atoms %{
    "accepted" => :accepted,
    "attached" => :attached,
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
        id: "jido.runs",
        site_id: @site_id,
        title: "Runs",
        provider: __MODULE__,
        resource_kinds: [:run, @state_kind],
        route_kind: :list_detail
      }),
      AppDescriptor.new!(%{
        id: "jido.boundary_sessions",
        site_id: @site_id,
        title: "Boundary Sessions",
        provider: __MODULE__,
        resource_kinds: [:boundary_session, @state_kind],
        route_kind: :list_detail
      }),
      AppDescriptor.new!(%{
        id: "jido.attach_grants",
        site_id: @site_id,
        title: "Attach Grants",
        provider: __MODULE__,
        resource_kinds: [:attach_grant, @state_kind],
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
    mapped_resources =
      run_resources(snapshot) ++
        boundary_session_resources(snapshot) ++ attach_grant_resources(snapshot)

    state_resources(snapshot, mapped_resources) ++ mapped_resources
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
  def detail(%Resource{kind: :run} = resource, snapshot) do
    snapshot
    |> Map.get(:runs, [])
    |> Enum.find(fn candidate -> field(candidate, :id) == resource.id end)
    |> case do
      nil ->
        missing_detail(resource)

      run ->
        ResourceDetail.new!(%{
          resource: resource,
          sections: [
            %{
              title: "Run",
              lines: [
                "status: #{field(run, :status)}",
                "capability: #{field(run, :capability_id)}",
                "runtime_class: #{field(run, :runtime_class)}",
                "target: #{field(run, :target_id) || "none"}",
                "tenant: #{field(run, :tenant_id) || "unknown"}",
                "streams: #{join_values(field(run, :stream_ids, []))}",
                "policy: #{safe_inspect(field(run, :policy, %{}))}"
              ]
            }
          ],
          recommended_actions: []
        })
    end
  end

  def detail(%Resource{kind: :boundary_session} = resource, snapshot) do
    snapshot
    |> Map.get(:boundary_sessions, [])
    |> Enum.find(fn candidate -> field(candidate, :id) == resource.id end)
    |> case do
      nil ->
        missing_detail(resource)

      session ->
        ResourceDetail.new!(%{
          resource: resource,
          sections: [
            %{
              title: "Boundary Session",
              lines: [
                "status: #{field(session, :status)}",
                "owner: #{field(session, :owner_id) || "unknown"}",
                "route: #{field(session, :route_id) || "none"}",
                "target: #{field(session, :target_id) || "none"}",
                "attach_grant: #{field(session, :attach_grant_id) || "none"}",
                "expires_at: #{field(session, :expires_at) || "none"}",
                "policy: #{safe_inspect(field(session, :policy, %{}))}"
              ]
            }
          ],
          recommended_actions: []
        })
    end
  end

  def detail(%Resource{kind: :attach_grant} = resource, snapshot) do
    snapshot
    |> Map.get(:attach_grants, [])
    |> Enum.find(fn candidate -> field(candidate, :id) == resource.id end)
    |> case do
      nil ->
        missing_detail(resource)

      attach_grant ->
        ResourceDetail.new!(%{
          resource: resource,
          sections: [
            %{
              title: "Attach Grant",
              lines: [
                "status: #{field(attach_grant, :status)}",
                "boundary_session: #{field(attach_grant, :boundary_session_id)}",
                "route: #{field(attach_grant, :route_id) || "none"}",
                "subject: #{field(attach_grant, :subject_id) || "none"}",
                "target: #{field(attach_grant, :target_id) || "none"}",
                "lease: #{field(attach_grant, :lease_id) || "none"}",
                "allowed_operations: #{join_values(field(attach_grant, :allowed_operations, []))}"
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

  defp run_resources(snapshot) do
    snapshot
    |> Map.get(:runs, [])
    |> Enum.map(fn run ->
      Resource.new!(%{
        site_id: @site_id,
        kind: :run,
        id: field(run, :id),
        title: field(run, :id),
        subtitle: field(run, :status),
        status: status_atom(field(run, :status)),
        capabilities: [:inspect],
        summary: field(run, :capability_id),
        ext: %{
          target_id: field(run, :target_id),
          tenant_id: field(run, :tenant_id),
          stream_ids: field(run, :stream_ids, [])
        }
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
        id: field(session, :id),
        title: field(session, :id),
        subtitle: field(session, :status),
        status: status_atom(field(session, :status)),
        capabilities: [:inspect],
        summary: field(session, :route_id) || field(session, :target_id) || "boundary",
        ext: %{
          owner_id: field(session, :owner_id),
          target_id: field(session, :target_id),
          attach_grant_id: field(session, :attach_grant_id)
        }
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
        id: field(attach_grant, :id),
        title: field(attach_grant, :id),
        subtitle: field(attach_grant, :status),
        status: status_atom(field(attach_grant, :status)),
        capabilities: [:inspect],
        summary: field(attach_grant, :boundary_session_id),
        ext: %{
          route_id: field(attach_grant, :route_id),
          subject_id: field(attach_grant, :subject_id),
          target_id: field(attach_grant, :target_id)
        }
      })
    end)
  end

  defp state_resources(snapshot, mapped_resources) do
    case site_state(snapshot) do
      nil when mapped_resources == [] ->
        [state_resource(:empty, "No Jido resources in snapshot")]

      nil ->
        []

      %{status: status} = state ->
        [state_resource(status_atom(status), field(state, :message) || "Jido #{status}")]
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
        Map.get(states, @site_id) || Map.get(states, String.to_atom(@site_id))

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

  defp normalize_query(query) do
    query
    |> String.trim()
    |> String.downcase()
  end

  defp join_values([]), do: "none"

  defp join_values(values) when is_list(values) do
    Enum.map_join(values, ", ", &to_string/1)
  end

  defp join_values(value), do: to_string(value)

  defp safe_inspect(value), do: inspect(redact(value))

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
