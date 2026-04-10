defmodule Switchyard.Site.JidoHive do
  @moduledoc """
  Jido Hive site mapping over generic Switchyard contracts.
  """

  @behaviour Switchyard.Contracts.SiteProvider

  alias Switchyard.Contracts.{
    Action,
    AppDescriptor,
    Resource,
    ResourceDetail,
    SiteDescriptor
  }

  @site_id "jido-hive"

  @impl true
  def site_definition do
    SiteDescriptor.new!(%{
      id: @site_id,
      title: "Jido Hive",
      provider: __MODULE__,
      kind: :remote,
      environment: "default",
      capabilities: [:apps, :actions, :resources]
    })
  end

  @impl true
  def apps do
    [
      AppDescriptor.new!(%{
        id: "jido-hive.rooms",
        site_id: @site_id,
        title: "Rooms",
        provider: __MODULE__,
        resource_kinds: [:room],
        route_kind: :list_detail
      }),
      AppDescriptor.new!(%{
        id: "jido-hive.publications",
        site_id: @site_id,
        title: "Publications",
        provider: __MODULE__,
        resource_kinds: [:publication],
        route_kind: :list_detail
      })
    ]
  end

  @impl true
  def actions do
    [
      Action.new!(%{
        id: "jido-hive.room.run",
        title: "Run room",
        scope: {:site, @site_id},
        provider: __MODULE__
      }),
      Action.new!(%{
        id: "jido-hive.room.provenance",
        title: "Inspect provenance",
        scope: {:resource, :room},
        provider: __MODULE__
      }),
      Action.new!(%{
        id: "jido-hive.room.publish",
        title: "Publish room output",
        scope: {:resource, :room},
        provider: __MODULE__,
        confirmation: :if_destructive
      })
    ]
  end

  @impl true
  def resources(snapshot) when is_map(snapshot) do
    rooms =
      snapshot
      |> Map.get(:rooms, [])
      |> Enum.map(&room_resource/1)

    publications =
      snapshot
      |> Map.get(:publications, [])
      |> Enum.map(&publication_resource/1)

    rooms ++ publications
  end

  @impl true
  def detail(%Resource{kind: :room} = resource, snapshot) do
    room =
      snapshot
      |> Map.get(:rooms, [])
      |> Enum.find(fn candidate -> candidate.id == resource.id end)

    ResourceDetail.new!(%{
      resource: resource,
      sections: [
        %{
          title: "Workflow",
          lines: [
            "stage: #{room.stage}",
            "next: #{room.next_action}",
            "publish ready: #{room.publish_ready}"
          ]
        }
      ],
      recommended_actions: ["Run room", "Inspect provenance", "Publish room output"]
    })
  end

  def detail(%Resource{kind: :publication} = resource, snapshot) do
    publication =
      snapshot
      |> Map.get(:publications, [])
      |> Enum.find(fn candidate -> candidate.id == resource.id end)

    ResourceDetail.new!(%{
      resource: resource,
      sections: [
        %{
          title: "Publication",
          lines: ["status: #{publication.status}", "target: #{publication.target}"]
        }
      ],
      recommended_actions: []
    })
  end

  defp room_resource(room) do
    Resource.new!(%{
      site_id: @site_id,
      kind: :room,
      id: room.id,
      title: room.title,
      subtitle: room.stage,
      status: room.status,
      tags: if(room.publish_ready, do: [:publish_ready], else: [:blocked]),
      capabilities: [:inspect, :run, :publish],
      summary: room.next_action
    })
  end

  defp publication_resource(publication) do
    Resource.new!(%{
      site_id: @site_id,
      kind: :publication,
      id: publication.id,
      title: publication.title,
      subtitle: publication.status,
      status: publication.status,
      capabilities: [:inspect],
      summary: publication.target
    })
  end
end
