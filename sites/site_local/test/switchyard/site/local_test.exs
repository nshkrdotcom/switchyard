defmodule Switchyard.Site.LocalTest do
  use ExUnit.Case, async: true

  alias Switchyard.Contracts.Resource
  alias Switchyard.Site.Local

  @snapshot %{
    processes: [
      %{id: "proc-1", label: "Server", status: "running", command: "mix phx.server"}
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
    assert detail.recommended_actions == ["Stop process"]
  end
end
