defmodule GenericSiteAdapter.DemoSite do
  @moduledoc """
  Minimal external Switchyard site provider example.
  """

  @behaviour Switchyard.Contracts.SiteProvider

  alias Switchyard.Contracts.{Action, AppDescriptor, Resource, ResourceDetail, SiteDescriptor}

  @site_id "generic_demo"

  @impl true
  def site_definition do
    SiteDescriptor.new!(%{
      id: @site_id,
      title: "Generic Demo",
      provider: __MODULE__,
      kind: :remote,
      capabilities: [:apps, :actions, :resources]
    })
  end

  @impl true
  def apps do
    [
      AppDescriptor.new!(%{
        id: "#{@site_id}.widgets",
        site_id: @site_id,
        title: "Widgets",
        provider: __MODULE__,
        resource_kinds: [:widget],
        route_kind: :list_detail
      })
    ]
  end

  @impl true
  def actions do
    [
      Action.new!(%{
        id: "#{@site_id}.widgets.refresh",
        title: "Refresh widgets",
        scope: {:site, @site_id},
        provider: __MODULE__
      })
    ]
  end

  @impl true
  def resources(snapshot) when is_map(snapshot) do
    snapshot
    |> Map.get(:widgets, default_widgets())
    |> Enum.map(&widget_resource/1)
  end

  @impl true
  def detail(%Resource{kind: :widget} = resource, snapshot) do
    widget =
      snapshot
      |> Map.get(:widgets, default_widgets())
      |> Enum.find(fn candidate -> candidate.id == resource.id end)

    ResourceDetail.new!(%{
      resource: resource,
      sections: [
        %{
          title: "Widget",
          lines: [
            "id: #{resource.id}",
            "owner: #{(widget && widget.owner) || "unknown"}",
            "tier: #{(widget && widget.tier) || "unknown"}"
          ]
        }
      ],
      recommended_actions: ["Refresh widgets"]
    })
  end

  defp default_widgets do
    [
      %{id: "widget-1", title: "Widget One", status: :ready, owner: "ops", tier: "gold"},
      %{id: "widget-2", title: "Widget Two", status: :degraded, owner: "eng", tier: "silver"}
    ]
  end

  defp widget_resource(widget) do
    Resource.new!(%{
      site_id: @site_id,
      kind: :widget,
      id: widget.id,
      title: widget.title,
      subtitle: Atom.to_string(widget.status),
      status: widget.status,
      summary: "#{widget.owner} / #{widget.tier}"
    })
  end
end
