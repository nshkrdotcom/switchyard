defmodule Switchyard.Site.ExecutionPlaneTest do
  use ExUnit.Case, async: true

  alias Switchyard.Contracts.{Resource, SiteDescriptor}
  alias Switchyard.Site.ExecutionPlane

  test "site definition and apps describe the execution plane surface" do
    assert %SiteDescriptor{id: "execution_plane", kind: :service} =
             ExecutionPlane.site_definition()

    assert Enum.map(ExecutionPlane.apps(), & &1.id) == [
             "execution_plane.processes",
             "execution_plane.operator_terminals",
             "execution_plane.jobs"
           ]
  end

  test "resources and detail render execution plane broker snapshots" do
    snapshot = %{
      processes: [
        %{
          id: "proc-1",
          label: "Example Proc",
          status: "running",
          command: "echo hi",
          command_preview: "echo hi",
          execution_surface: %{"surface_kind" => "ssh_exec", "target_id" => "demo.internal"},
          sandbox: %{"mode" => "read_only"}
        }
      ],
      operator_terminals: [
        %{
          id: "ops-1",
          surface_kind: "ssh_terminal",
          status: "running",
          boundary_class: "operator_ui",
          surface_ref: "ops-ref-1"
        }
      ],
      jobs: [
        %{
          id: "job-1",
          title: "Start Example Proc",
          status: :running,
          progress: %{current: 0, total: 1}
        }
      ]
    }

    resources = ExecutionPlane.resources(snapshot)

    assert Enum.any?(resources, &match?(%Resource{id: "proc-1", kind: :process}, &1))
    assert Enum.any?(resources, &match?(%Resource{id: "ops-1", kind: :operator_terminal}, &1))

    detail =
      resources
      |> Enum.find(&(&1.id == "proc-1"))
      |> then(&ExecutionPlane.detail(&1, snapshot))

    assert Enum.any?(List.flatten(Enum.map(detail.sections, & &1.lines)), &(&1 =~ "ssh_exec"))
  end
end
