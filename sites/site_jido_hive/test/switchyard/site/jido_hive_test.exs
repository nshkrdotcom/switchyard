defmodule Switchyard.Site.JidoHiveTest do
  use ExUnit.Case, async: true

  alias Switchyard.Contracts.Resource
  alias Switchyard.Site.JidoHive

  @snapshot %{
    rooms: [
      %{
        id: "room-1",
        title: "Planning Room",
        stage: "publication_ready",
        next_action: "Publish canonical output",
        publish_ready: true,
        status: :ready
      }
    ],
    publications: [
      %{id: "pub-1", title: "Draft Publication", status: :queued, target: "demo-target"}
    ]
  }

  test "describes the site and its apps" do
    assert JidoHive.site_definition().id == "jido-hive"
    assert Enum.map(JidoHive.apps(), & &1.id) == ["jido-hive.rooms", "jido-hive.publications"]
  end

  test "maps room and publication resources" do
    resources = JidoHive.resources(@snapshot)

    assert Enum.any?(resources, &(&1.kind == :room and &1.id == "room-1"))
    assert Enum.any?(resources, &(&1.kind == :publication and &1.id == "pub-1"))
  end

  test "builds room workflow detail" do
    room =
      Resource.new!(%{
        site_id: "jido-hive",
        kind: :room,
        id: "room-1",
        title: "Planning Room",
        capabilities: [:inspect]
      })

    detail = JidoHive.detail(room, @snapshot)

    assert [%{title: "Workflow"}] = detail.sections
    assert Enum.member?(detail.recommended_actions, "Publish room output")
  end
end
