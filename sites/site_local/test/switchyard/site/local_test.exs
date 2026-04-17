defmodule Switchyard.Site.LocalTest do
  use ExUnit.Case, async: true

  alias Switchyard.Contracts.Resource
  alias Switchyard.Site.Local

  @snapshot %{
    processes: [
      %{
        id: "proc-1",
        label: "Server",
        status: "running",
        command: "mix phx.server",
        command_preview: "ssh deploy@app.internal sh -lc 'mix phx.server'",
        execution_surface: %{
          "surface_kind" => "ssh_exec",
          "target_id" => "app.internal",
          "boundary_class" => "operator",
          "transport_options" => %{"user" => "deploy", "port" => 2222}
        },
        sandbox: %{
          "mode" => "read_only",
          "policy" => %{"network_access" => "restricted", "has_command_prefix" => true}
        }
      }
    ],
    jobs: [
      %{id: "job-1", title: "Start server", status: :running, progress: %{current: 1, total: 2}}
    ]
  }

  test "describes the site and apps" do
    assert Local.site_definition().id == "local"
    assert Enum.map(Local.apps(), & &1.id) == ["local.processes", "local.jobs", "local.logs"]
  end

  test "maps snapshot resources" do
    resources = Local.resources(@snapshot)

    assert Enum.any?(resources, &(&1.kind == :process and &1.id == "proc-1"))
    assert Enum.any?(resources, &(&1.kind == :job and &1.id == "job-1"))
    assert Enum.any?(resources, &(&1.summary =~ "ssh deploy@app.internal"))
  end

  test "builds detail views from resources and snapshot" do
    resource =
      Resource.new!(%{
        site_id: "local",
        kind: :process,
        id: "proc-1",
        title: "Server",
        capabilities: [:inspect]
      })

    detail = Local.detail(resource, @snapshot)

    assert [%{title: "Process"}] = detail.sections
    assert Enum.any?(hd(detail.sections).lines, &String.contains?(&1, "surface: ssh_exec"))
    assert Enum.any?(hd(detail.sections).lines, &String.contains?(&1, "sandbox: read_only"))
    assert detail.recommended_actions == ["Stop process"]
  end
end
