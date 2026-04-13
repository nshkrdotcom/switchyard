defmodule Switchyard.ContractsTest do
  use ExUnit.Case, async: true

  alias Switchyard.Contracts.{
    Action,
    ActionResult,
    AppDescriptor,
    Job,
    LogEvent,
    Resource,
    ResourceDetail,
    SearchResult,
    SiteDescriptor,
    StreamDescriptor
  }

  test "builds site and app descriptors" do
    site =
      SiteDescriptor.new!(%{
        id: "local",
        title: "Local",
        provider: __MODULE__,
        capabilities: [:apps, :actions]
      })

    app =
      AppDescriptor.new!(%{
        id: "local.processes",
        site_id: site.id,
        title: "Processes",
        provider: __MODULE__,
        resource_kinds: [:process],
        tui_component: Workbench.Widgets.Pane
      })

    assert site.id == "local"
    assert app.resource_kinds == [:process]
    assert app.tui_component == Workbench.Widgets.Pane
  end

  test "builds resource, detail, action, and action result contracts" do
    resource =
      Resource.new!(%{
        site_id: "local",
        kind: :process,
        id: "proc-1",
        title: "Echo Process",
        capabilities: [:inspect, :stop]
      })

    detail =
      ResourceDetail.new!(%{
        resource: resource,
        sections: [%{title: "Summary", lines: ["running"]}],
        recommended_actions: ["stop process"]
      })

    action =
      Action.new!(%{
        id: "local.process.stop",
        title: "Stop process",
        scope: {:resource, :process},
        provider: __MODULE__
      })

    result = ActionResult.new!(%{status: :accepted, message: "queued", job_id: "job-1"})

    assert detail.resource.id == "proc-1"
    assert action.confirmation == :never
    assert result.job_id == "job-1"
  end

  test "builds stream, job, search, and log contracts" do
    stream =
      StreamDescriptor.new!(%{
        id: "logs/proc-1",
        kind: :log,
        subject: {:process, "proc-1"}
      })

    job =
      Job.new!(%{
        id: "job-1",
        kind: :process_start,
        title: "Start echo",
        status: :running
      })

    search =
      SearchResult.new!(%{
        id: "search-1",
        kind: :resource,
        title: "Echo Process",
        action: {:open_resource, {:process, "proc-1"}},
        score: 0.98
      })

    log =
      LogEvent.new!(%{
        at: DateTime.utc_now(),
        level: :info,
        source_kind: :process,
        source_id: "proc-1",
        stream_id: stream.id,
        message: "hello"
      })

    assert job.status == :running
    assert search.score > 0.9
    assert log.stream_id == "logs/proc-1"
  end

  test "raises on missing required keys" do
    assert_raise ArgumentError, fn ->
      Resource.new!(%{site_id: "local"})
    end
  end
end
