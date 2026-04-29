defmodule Switchyard.Site.ExecutionPlaneTest do
  use ExUnit.Case, async: true

  alias Switchyard.Contracts.{Resource, SearchResult, SiteDescriptor}
  alias Switchyard.Site.ExecutionPlane

  @snapshot %{
    processes: [
      %{
        id: "proc-1",
        label: "Example Proc",
        status: :running,
        status_reason: :runtime_started,
        exit_status: nil,
        job_ids: ["job-proc-1"],
        stream_ids: ["logs/proc-1"],
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
        progress: %{current: 0, total: 1},
        stream_ids: ["jobs/job-1"],
        process_ids: ["proc-1"]
      }
    ],
    streams: [
      %{
        id: "logs/proc-1",
        kind: :process_combined,
        subject: {:process, "proc-1"},
        retention: :bounded,
        capabilities: [:tail, :filter]
      },
      %{
        id: "jobs/job-1",
        kind: :job_events,
        subject: {:job, "job-1"},
        retention: :bounded,
        capabilities: [:tail]
      }
    ]
  }

  test "site definition and apps describe the execution plane surface" do
    assert %SiteDescriptor{id: "execution_plane", kind: :service} =
             ExecutionPlane.site_definition()

    assert Enum.map(ExecutionPlane.apps(), & &1.id) == [
             "execution_plane.processes",
             "execution_plane.operator_terminals",
             "execution_plane.jobs",
             "execution_plane.streams"
           ]
  end

  test "resources and detail render execution plane broker snapshots" do
    resources = ExecutionPlane.resources(@snapshot)

    assert Enum.any?(resources, &match?(%Resource{id: "proc-1", kind: :process}, &1))
    assert Enum.any?(resources, &match?(%Resource{id: "ops-1", kind: :operator_terminal}, &1))
    assert Enum.any?(resources, &match?(%Resource{id: "job-1", kind: :job}, &1))
    assert Enum.any?(resources, &match?(%Resource{id: "logs/proc-1", kind: :stream}, &1))

    detail =
      resources
      |> Enum.find(&(&1.id == "proc-1"))
      |> then(&ExecutionPlane.detail(&1, @snapshot))

    assert Enum.any?(List.flatten(Enum.map(detail.sections, & &1.lines)), &(&1 =~ "ssh_exec"))

    assert Enum.any?(
             List.flatten(Enum.map(detail.sections, & &1.lines)),
             &(&1 =~ "runtime_started")
           )

    assert Enum.any?(List.flatten(Enum.map(detail.sections, & &1.lines)), &(&1 =~ "logs/proc-1"))
  end

  test "job and stream details include backing links" do
    resources = ExecutionPlane.resources(@snapshot)

    job_detail =
      resources
      |> Enum.find(&(&1.id == "job-1"))
      |> ExecutionPlane.detail(@snapshot)

    assert detail_lines(job_detail) =~ "streams: jobs/job-1"
    assert detail_lines(job_detail) =~ "processes: proc-1"

    stream_detail =
      resources
      |> Enum.find(&(&1.id == "logs/proc-1"))
      |> ExecutionPlane.detail(@snapshot)

    assert detail_lines(stream_detail) =~ "subject: process proc-1"
    assert detail_lines(stream_detail) =~ "capabilities: tail, filter"
  end

  test "operator terminal detail distinguishes UI transport from managed-process attach" do
    detail =
      @snapshot
      |> ExecutionPlane.resources()
      |> Enum.find(&(&1.kind == :operator_terminal))
      |> ExecutionPlane.detail(@snapshot)

    lines = detail_lines(detail)

    assert lines =~ "purpose: operator UI transport"
    assert lines =~ "managed_process_attach: no"
  end

  test "empty unavailable degraded and error states are explicit resources" do
    assert [%Resource{kind: :site_state, status: :empty, title: "Execution Plane empty"}] =
             ExecutionPlane.resources(%{
               processes: [],
               operator_terminals: [],
               jobs: [],
               streams: []
             })

    for status <- [:unavailable, :degraded, :error] do
      resources =
        ExecutionPlane.resources(%{
          site_states: %{
            "execution_plane" => %{status: status, message: "runtime #{status}"}
          }
        })

      assert [%Resource{kind: :site_state, status: ^status}] = resources
      assert hd(resources).summary == "runtime #{status}"
    end
  end

  test "search returns typed navigation results without secret metadata" do
    snapshot =
      Map.update!(@snapshot, :processes, fn [process] ->
        [Map.put(process, :metadata, %{"token" => "secret-token", "owner" => "ops"})]
      end)

    assert [%SearchResult{} | _] = results = ExecutionPlane.search("proc-1", snapshot)

    assert Enum.any?(
             results,
             &(&1.action == {:open_resource, {"execution_plane", :process, "proc-1"}})
           )

    refute results
           |> Enum.map_join("\n", &inspect/1)
           |> String.contains?("secret-token")
  end

  defp detail_lines(detail) do
    detail.sections
    |> Enum.flat_map(& &1.lines)
    |> Enum.join("\n")
  end
end
