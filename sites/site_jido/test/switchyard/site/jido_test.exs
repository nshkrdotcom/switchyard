defmodule Switchyard.Site.JidoTest do
  use ExUnit.Case, async: true

  alias Switchyard.Contracts.{Resource, SiteDescriptor}
  alias Switchyard.Site.Jido

  test "site definition and apps describe the durable jido surface" do
    assert %SiteDescriptor{id: "jido", kind: :service} = Jido.site_definition()

    assert Enum.map(Jido.apps(), & &1.id) == [
             "jido.runs",
             "jido.boundary_sessions",
             "jido.attach_grants"
           ]
  end

  test "resources and detail render durable run state" do
    snapshot = %{
      runs: [
        %{
          id: "run-1",
          capability_id: "codex.exec",
          runtime_class: "session",
          status: "completed",
          target_id: "target-1",
          tenant_id: "tenant-1"
        }
      ],
      boundary_sessions: [
        %{
          id: "boundary-1",
          status: "attached",
          route_id: "route-1",
          target_id: "target-1",
          attach_grant_id: "grant-1"
        }
      ],
      attach_grants: [
        %{
          id: "grant-1",
          status: "issued",
          boundary_session_id: "boundary-1",
          route_id: "route-1",
          subject_id: "run-1"
        }
      ]
    }

    resources = Jido.resources(snapshot)

    assert Enum.any?(resources, &match?(%Resource{id: "run-1", kind: :run}, &1))
    assert Enum.any?(resources, &match?(%Resource{id: "boundary-1", kind: :boundary_session}, &1))
    assert Enum.any?(resources, &match?(%Resource{id: "grant-1", kind: :attach_grant}, &1))

    detail =
      resources
      |> Enum.find(&(&1.id == "run-1"))
      |> then(&Jido.detail(&1, snapshot))

    assert Enum.any?(List.flatten(Enum.map(detail.sections, & &1.lines)), &(&1 =~ "codex.exec"))
  end
end
