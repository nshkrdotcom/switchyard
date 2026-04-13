#!/usr/bin/env elixir

repo_root = Path.expand("..", __DIR__)

Mix.install([
  {:ex_ratatui, "~> 0.7.0"},
  {:switchyard_tui, path: Path.join(repo_root, "apps/terminal_workbench_tui")},
  {:workbench_devtools, path: Path.join(repo_root, "core/workbench_devtools")}
])

defmodule Switchyard.Examples.FullFeatured.Data do
  @moduledoc false

  def base_snapshot do
    %{
      processes: [
        %{
          id: "proc-edge",
          label: "Edge proxy",
          command: "bin/edge-proxy --listen 0.0.0.0:8443",
          status: "running"
        },
        %{
          id: "proc-worker",
          label: "Batch worker",
          command: "bin/batch-worker --queues deploy,report",
          status: "running"
        }
      ],
      jobs: [
        %{
          id: "job-142",
          title: "Deploy api-gateway",
          status: :running,
          progress: %{current: 17, total: 20}
        },
        %{
          id: "job-155",
          title: "Verify queue health",
          status: :queued,
          progress: %{current: 0, total: 5}
        }
      ],
      runbooks: [
        %{
          id: "rb-rollback",
          title: "Rollback saturated deployment",
          subtitle: "critical path",
          owner: "platform",
          summary: "Drain traffic, pause rollout, and restore the previous release.",
          steps: [
            "Pause progressive delivery for the selected service.",
            "Shift 100% of traffic back to the previous revision.",
            "Verify queue depth and p95 latency return to baseline."
          ]
        },
        %{
          id: "rb-cache",
          title: "Recover cache tier",
          subtitle: "warm standby",
          owner: "runtime",
          summary: "Promote the standby cache and rebuild hot keys.",
          steps: [
            "Promote the warm standby shard.",
            "Replay the top 100 hot keys from the snapshot export.",
            "Re-enable cache writes once hit rate reaches 90%."
          ]
        }
      ],
      incidents: [
        %{
          id: "inc-301",
          title: "Elevated queue depth in deploy lane",
          subtitle: "critical",
          severity: :critical,
          owner: "platform",
          summary: "Deploy queue depth exceeded the SLO window for 14 minutes.",
          runbook_id: "rb-rollback"
        },
        %{
          id: "inc-318",
          title: "Search index lag",
          subtitle: "warn",
          severity: :warn,
          owner: "search",
          summary: "Index lag is 92 seconds behind the write stream.",
          runbook_id: "rb-cache"
        }
      ]
    }
  end

  def dashboard_payload(refresh_count) when is_integer(refresh_count) and refresh_count >= 0 do
    cluster_health = [0.88, 0.91, 0.86, 0.93] |> Enum.at(rem(refresh_count, 4))
    queue_depth = [7, 5, 4, 3] |> Enum.at(rem(refresh_count, 4))
    throughput_rps = 1_820 + refresh_count * 35

    services = [
      %{
        id: "api-gateway",
        owner: "edge",
        slo: "99.95%",
        status: service_status(refresh_count, 0),
        latency_ms: 24 + rem(refresh_count * 3, 7),
        desired_instances: 8,
        ready_instances: if(rem(refresh_count, 4) == 2, do: 7, else: 8)
      },
      %{
        id: "billing",
        owner: "payments",
        slo: "99.90%",
        status: service_status(refresh_count, 1),
        latency_ms: 39 + rem(refresh_count * 2, 6),
        desired_instances: 6,
        ready_instances: 6
      },
      %{
        id: "search",
        owner: "catalog",
        slo: "99.80%",
        status: service_status(refresh_count, 2),
        latency_ms: 58 + rem(refresh_count * 5, 11),
        desired_instances: 12,
        ready_instances: if(rem(refresh_count, 3) == 0, do: 11, else: 12)
      }
    ]

    jobs = [
      %{
        id: "deploy-142",
        title: "Roll api-gateway canary",
        status: job_status(refresh_count, 0),
        worker: "edge-a",
        current: 5 + rem(refresh_count * 2, 6),
        total: 10
      },
      %{
        id: "verify-155",
        title: "Queue saturation sweep",
        status: job_status(refresh_count, 1),
        worker: "platform-b",
        current: 2 + rem(refresh_count, 3),
        total: 5
      },
      %{
        id: "reindex-204",
        title: "Catalog delta replay",
        status: job_status(refresh_count, 2),
        worker: "search-c",
        current: 9 + rem(refresh_count * 3, 4),
        total: 12
      }
    ]

    incidents = [
      %{
        id: "inc-301",
        title: "Deploy lane queue depth",
        severity: if(queue_depth >= 6, do: :critical, else: :warn),
        owner: "platform",
        summary: "Deploy queue depth remains above the steady-state target.",
        runbook: "Rollback saturated deployment"
      },
      %{
        id: "inc-318",
        title: "Search index lag",
        severity: if(rem(refresh_count, 3) == 0, do: :warn, else: :ready),
        owner: "search",
        summary: "Replication lag is noisy but bounded.",
        runbook: "Recover cache tier"
      }
    ]

    %{
      refresh_count: refresh_count,
      cluster_health: cluster_health,
      queue_depth: queue_depth,
      throughput_rps: throughput_rps,
      services: services,
      jobs: jobs,
      incidents: incidents,
      recommended_action:
        if(queue_depth >= 6,
          do: "Pause the active rollout and drain the deploy queue.",
          else: "Hold steady and keep the canary moving."
        ),
      note:
        if(refresh_count == 0,
          do: "Initial dashboard payload loaded from the request handler.",
          else: "Refresh ##{refresh_count} completed without transport errors."
        )
    }
  end

  def deploy_payload(service_id, refresh_count) when is_binary(service_id) do
    %{
      service_id: service_id,
      refresh_count: refresh_count,
      ticket: "deploy-#{refresh_count + 200}",
      stage: "Canary rollout",
      percent: 0.18
    }
  end

  def ack_payload(incident_id) when is_binary(incident_id) do
    %{incident_id: incident_id, state: :acknowledged}
  end

  defp service_status(refresh_count, offset) do
    case rem(refresh_count + offset, 5) do
      0 -> "steady"
      1 -> "steady"
      2 -> "observing"
      3 -> "draining"
      _other -> "steady"
    end
  end

  defp job_status(refresh_count, offset) do
    case rem(refresh_count + offset, 4) do
      0 -> "running"
      1 -> "running"
      2 -> "queued"
      _other -> "verifying"
    end
  end
end

defmodule Switchyard.Examples.FullFeatured.DemoSite do
  @moduledoc false

  @behaviour Switchyard.Contracts.SiteProvider

  alias Switchyard.Contracts.{
    AppDescriptor,
    Resource,
    ResourceDetail,
    SiteDescriptor
  }

  @site_id "fleet_demo"

  @impl true
  def site_definition do
    SiteDescriptor.new!(%{
      id: @site_id,
      title: "Fleet Demo",
      provider: __MODULE__,
      kind: :remote,
      environment: "staging",
      capabilities: [:apps, :resources]
    })
  end

  @impl true
  def apps do
    [
      AppDescriptor.new!(%{
        id: "#{@site_id}.control_room",
        site_id: @site_id,
        title: "Control Room",
        provider: __MODULE__,
        route_kind: :workspace,
        tui_component: Switchyard.Examples.FullFeatured.ControlRoom
      }),
      AppDescriptor.new!(%{
        id: "#{@site_id}.runbooks",
        site_id: @site_id,
        title: "Runbooks",
        provider: __MODULE__,
        resource_kinds: [:runbook],
        route_kind: :list_detail
      }),
      AppDescriptor.new!(%{
        id: "#{@site_id}.incidents",
        site_id: @site_id,
        title: "Incidents",
        provider: __MODULE__,
        resource_kinds: [:incident],
        route_kind: :list_detail
      })
    ]
  end

  @impl true
  def actions, do: []

  @impl true
  def resources(snapshot) when is_map(snapshot) do
    runbooks =
      snapshot
      |> Map.get(:runbooks, [])
      |> Enum.map(&runbook_resource/1)

    incidents =
      snapshot
      |> Map.get(:incidents, [])
      |> Enum.map(&incident_resource/1)

    runbooks ++ incidents
  end

  @impl true
  def detail(%Resource{kind: :runbook} = resource, snapshot) do
    runbook =
      snapshot
      |> Map.get(:runbooks, [])
      |> Enum.find(fn candidate -> candidate.id == resource.id end)

    ResourceDetail.new!(%{
      resource: resource,
      sections: [
        %{title: "Summary", lines: [runbook.summary, "owner: #{runbook.owner}"]},
        %{title: "Steps", lines: runbook.steps}
      ],
      recommended_actions: ["Open Control Room", "Stage a rollback"]
    })
  end

  def detail(%Resource{kind: :incident} = resource, snapshot) do
    incident =
      snapshot
      |> Map.get(:incidents, [])
      |> Enum.find(fn candidate -> candidate.id == resource.id end)

    ResourceDetail.new!(%{
      resource: resource,
      sections: [
        %{
          title: "Incident",
          lines: [
            "owner: #{incident.owner}",
            "severity: #{incident.severity}",
            "runbook: #{incident.runbook_id}"
          ]
        },
        %{title: "Summary", lines: [incident.summary]}
      ],
      recommended_actions: ["Acknowledge incident", "Open #{incident.runbook_id}"]
    })
  end

  defp runbook_resource(runbook) do
    Resource.new!(%{
      site_id: @site_id,
      kind: :runbook,
      id: runbook.id,
      title: runbook.title,
      subtitle: runbook.subtitle,
      status: :ready,
      capabilities: [:inspect],
      summary: runbook.summary
    })
  end

  defp incident_resource(incident) do
    Resource.new!(%{
      site_id: @site_id,
      kind: :incident,
      id: incident.id,
      title: incident.title,
      subtitle: incident.subtitle,
      status: incident.severity,
      capabilities: [:inspect],
      summary: incident.summary
    })
  end
end

defmodule Switchyard.Examples.FullFeatured.ControlLoopActor do
  @moduledoc false

  @behaviour Workbench.Component

  alias Workbench.{Cmd, Context, Style, Subscription}
  alias Workbench.Widgets.Spinner

  @pulse_ms 650

  @impl true
  def mode, do: :supervised

  @impl true
  def init(_props, %Context{} = ctx) do
    {:ok,
     %{
       step: 0,
       ticks: 0,
       mounted_path: ctx.path
     }, commands: Cmd.message({:mounted_actor_ready, ctx.path})}
  end

  @impl true
  def update(_msg, _state, _props, _ctx), do: :unhandled

  @impl true
  def handle_info(:control_loop_pulse, state, _props, _ctx) do
    next_state = %{state | step: state.step + 1, ticks: state.ticks + 1}
    {:ok, next_state, commands: Cmd.message({:mounted_actor_tick, next_state.ticks})}
  end

  def handle_info(_msg, _state, _props, _ctx), do: :unhandled

  @impl true
  def subscriptions(_state, _props, _ctx) do
    [Subscription.interval(:control_loop_pulse, @pulse_ms, :control_loop_pulse)]
  end

  @impl true
  def render(state, props, _ctx) do
    Spinner.new(
      id: :control_loop_actor,
      title: Map.get(props, :title, "Control Loop"),
      label:
        "#{Map.get(props, :label, "subscriptions + async requests")}  ·  ticks #{state.ticks}",
      step: state.step
    )
    |> Style.border_fg(:surface_alt)
  end
end

defmodule Switchyard.Examples.FullFeatured.ControlRoom do
  @moduledoc false

  @behaviour Workbench.Component

  alias Switchyard.Examples.FullFeatured.ControlLoopActor
  alias Workbench.{Cmd, Context, Keymap, Layout, Node, Style, Subscription}

  alias Workbench.Widgets.{
    Detail,
    Help,
    List,
    Pane,
    ProgressBar,
    StatusBar,
    Table,
    Tabs,
    WidgetList
  }

  @tab_titles ["Services", "Jobs", "Incidents", "Runtime"]
  @runtime_refresh_ms 1_250

  @impl true
  def init(props, %Context{} = ctx) do
    snapshot = Map.get(props, :snapshot, %{})
    initial_trace? = Map.get(props, :initial_trace?, true)

    state = %{
      server_pid: self(),
      active_tab: 0,
      service_cursor: 0,
      job_cursor: 0,
      incident_cursor: 0,
      refresh_count: 0,
      last_refresh_at: format_datetime(ctx.clock.()),
      cluster_health: 0.0,
      queue_depth: 0,
      throughput_rps: 0,
      recommended_action: "Awaiting the first request handler response.",
      snapshot_summary: "profiling local snapshot",
      services: [],
      jobs: [],
      incidents: [],
      rollout: %{service_id: nil, stage: "Idle", percent: 0.0},
      acknowledged_incidents: MapSet.new(),
      logs: [
        "[boot] control room mounted",
        "[boot] local snapshot captured with #{length(Map.get(snapshot, :processes, []))} processes",
        "[boot] quiet runtime polling will refresh the observability tab without forcing a repaint",
        "[boot] mounted control-loop actor will own its own spinner pulse"
      ],
      status_line: "Booting Fleet Demo control room.",
      status_severity: :warn,
      runtime_snapshot: empty_runtime_snapshot(initial_trace?),
      trace_enabled: initial_trace?,
      trace_scroll_offset: 0,
      last_probe_lines: [
        "Reducer runtime trace is #{if(initial_trace?, do: "enabled", else: "disabled")}.",
        "Press t to toggle capture and s to request a fresh runtime snapshot.",
        "Press x to trigger a failing async diagnostic probe."
      ]
    }

    boot_commands =
      Cmd.batch([
        dashboard_request(0),
        Cmd.async(fn -> summarize_snapshot(snapshot) end, &{:snapshot_summary_ready, &1}),
        Cmd.after_ms(120, {:append_log, "[boot] command batch completed"}),
        Cmd.after_ms(200, {:append_log, "[boot] observability subscriptions armed"})
      ])

    {:ok, state, commands: boot_commands, trace?: initial_trace?}
  end

  @impl true
  def render(state, props, ctx) do
    Node.vstack(
      :control_room,
      [
        Pane.new(
          id: :header,
          title: "Fleet Demo Control Room",
          lines: [
            "Switchyard site catalog + Workbench component seam + ex_ratatui reducer runtime",
            "Runtime tab shows trace events, quiet snapshot polling, async failure normalization, and row-based WidgetList scrolling. Distributed mode is available with --distributed / --attach."
          ]
        )
        |> Style.border_fg(:accent),
        Tabs.new(id: :tabs, titles: @tab_titles, selected: state.active_tab),
        content_panel(state, props),
        Help.new(
          id: :help,
          title: "Keys",
          lines: help_lines(state, ctx)
        )
        |> Style.border_fg(:muted),
        StatusBar.new(
          id: :status,
          text: state.status_line
        )
        |> Style.fg(status_tone(state.status_severity))
      ],
      constraints: [
        {:length, 4},
        {:length, 1},
        {:min, 18},
        {:length, 4},
        {:length, 1}
      ]
    )
    |> Layout.with_padding({1, 1, 0, 0})
  end

  @impl true
  def update(:tab_left, state, _props, _ctx) do
    {:ok,
     %{state | active_tab: rem(state.active_tab + length(@tab_titles) - 1, length(@tab_titles))},
     []}
  end

  def update(:tab_right, state, _props, _ctx) do
    {:ok, %{state | active_tab: rem(state.active_tab + 1, length(@tab_titles))}, []}
  end

  def update(:jump_runtime, state, _props, _ctx) do
    {:ok, %{state | active_tab: 3}, []}
  end

  def update(:select_prev, %{active_tab: 3} = state, _props, %Context{} = ctx) do
    {:ok, scroll_trace(state, -1, ctx), []}
  end

  def update(:select_prev, state, _props, _ctx), do: {:ok, move_cursor(state, -1), []}

  def update(:select_next, %{active_tab: 3} = state, _props, %Context{} = ctx) do
    {:ok, scroll_trace(state, 1, ctx), []}
  end

  def update(:select_next, state, _props, _ctx), do: {:ok, move_cursor(state, 1), []}

  def update(:snapshot_now, state, _props, _ctx) do
    next_state =
      state
      |> put_status("Requested an on-demand runtime snapshot.", :info)
      |> append_log("[action] runtime snapshot requested")

    {:ok, next_state, commands: runtime_snapshot_command(state.server_pid)}
  end

  def update(:toggle_trace, state, _props, _ctx) do
    enabled? = not state.trace_enabled

    next_state =
      state
      |> put_status("Toggling runtime trace #{if(enabled?, do: "on", else: "off")}.", :warn)
      |> append_log("[action] runtime trace toggle requested")

    {:ok, next_state, commands: trace_toggle_command(state.server_pid, enabled?)}
  end

  def update(:run_failing_probe, state, _props, _ctx) do
    next_state =
      state
      |> put_status("Running a failing async diagnostic probe.", :warn)
      |> append_log("[action] failing diagnostic probe requested")

    {:ok, next_state, commands: failing_probe_command()}
  end

  def update(:refresh, state, _props, _ctx) do
    next_state =
      state
      |> put_status("Refreshing dashboard via Workbench request handler.", :info)
      |> append_log("[action] manual refresh requested")

    {:ok, next_state, commands: dashboard_request(state.refresh_count + 1)}
  end

  def update(:deploy_selected, state, _props, _ctx) do
    case selected_service(state) do
      nil ->
        {:ok, put_status(state, "No service selected for deployment.", :warn), []}

      service ->
        next_state =
          state
          |> put_status("Requested canary deploy for #{service.id}.", :warn)
          |> append_log("[action] deploy requested for #{service.id}")

        {:ok, next_state,
         commands:
           Cmd.request(
             {:deploy_service, service.id, state.refresh_count},
             [],
             &{:deploy_started, &1}
           )}
    end
  end

  def update(:ack_selected, state, _props, _ctx) do
    case selected_incident(state) do
      nil ->
        {:ok, put_status(state, "No incident selected to acknowledge.", :warn), []}

      incident ->
        next_state =
          state
          |> put_status("Acknowledging #{incident.id}.", :warn)
          |> append_log("[action] acknowledging #{incident.id}")

        {:ok, next_state,
         commands: Cmd.request({:ack_incident, incident.id}, [], &{:incident_acknowledged, &1})}
    end
  end

  def update(_msg, _state, _props, _ctx), do: :unhandled

  @impl true
  def handle_info(:pulse, state, _props, _ctx) do
    {:ok, advance_rollout(state), []}
  end

  def handle_info(:auto_refresh, state, _props, _ctx) do
    next_state =
      state
      |> put_status("Periodic refresh fired from the subscription loop.", :info)
      |> append_log("[subscription] periodic refresh ##{state.refresh_count + 1}")

    {:ok, next_state, commands: dashboard_request(state.refresh_count + 1)}
  end

  def handle_info(:runtime_refresh, state, _props, _ctx) do
    {:ok, state, commands: runtime_snapshot_command(state.server_pid), render?: false}
  end

  def handle_info({:dashboard_loaded, payload}, state, _props, %Context{} = ctx) do
    next_state =
      state
      |> Map.put(:refresh_count, payload.refresh_count)
      |> Map.put(:last_refresh_at, format_datetime(ctx.clock.()))
      |> Map.put(:cluster_health, payload.cluster_health)
      |> Map.put(:queue_depth, payload.queue_depth)
      |> Map.put(:throughput_rps, payload.throughput_rps)
      |> Map.put(:recommended_action, payload.recommended_action)
      |> Map.put(:services, payload.services)
      |> Map.put(:jobs, payload.jobs)
      |> Map.put(:incidents, payload.incidents)
      |> put_status(payload.note, :info)
      |> append_log("[request] dashboard refresh ##{payload.refresh_count} applied")

    {:ok, next_state, []}
  end

  def handle_info({:snapshot_summary_ready, summary}, state, _props, _ctx) do
    next_state =
      state
      |> Map.put(:snapshot_summary, summary)
      |> append_log("[async] #{summary}")

    {:ok, next_state, []}
  end

  def handle_info({:runtime_snapshot_ready, snapshot}, state, _props, %Context{} = ctx) do
    next_state =
      state
      |> Map.put(:runtime_snapshot, snapshot)
      |> Map.put(:trace_enabled, snapshot.trace_enabled?)
      |> Map.put(
        :trace_scroll_offset,
        clamp_trace_scroll(snapshot, state.trace_scroll_offset, ctx)
      )

    {:ok, next_state, []}
  end

  def handle_info({:trace_toggle_applied, enabled?}, state, _props, _ctx) do
    next_state =
      state
      |> Map.put(:trace_enabled, enabled?)
      |> put_status("Runtime trace #{if(enabled?, do: "enabled", else: "disabled")}.", :info)
      |> append_log("[runtime] trace #{if(enabled?, do: "enabled", else: "disabled")}")

    {:ok, next_state, commands: runtime_snapshot_command(state.server_pid)}
  end

  def handle_info({:diagnostic_probe_finished, {:error, reason}}, state, _props, _ctx) do
    next_state =
      state
      |> Map.put(:last_probe_lines, diagnostic_failure_lines(reason))
      |> put_status("Diagnostic probe failed in a controlled way.", :error)
      |> append_log("[async] diagnostic failure #{inspect(reason)}")

    {:ok, next_state, commands: runtime_snapshot_command(state.server_pid)}
  end

  def handle_info({:deploy_started, payload}, state, _props, _ctx) do
    next_state =
      state
      |> Map.put(:rollout, %{
        service_id: payload.service_id,
        stage: payload.stage,
        percent: payload.percent
      })
      |> put_status("Deploy ticket #{payload.ticket} opened for #{payload.service_id}.", :warn)
      |> append_log("[request] deploy ticket #{payload.ticket} opened")

    {:ok, next_state, commands: Cmd.after_ms(1_200, {:rollout_completed, payload.service_id})}
  end

  def handle_info({:rollout_completed, service_id}, state, _props, _ctx) do
    next_state =
      state
      |> Map.put(:rollout, %{service_id: service_id, stage: "Stable", percent: 1.0})
      |> put_status("#{service_id} reached stable after the canary.", :info)
      |> append_log("[timer] rollout completed for #{service_id}")

    {:ok, next_state, []}
  end

  def handle_info({:incident_acknowledged, payload}, state, _props, _ctx) do
    next_state =
      state
      |> Map.update!(:acknowledged_incidents, &MapSet.put(&1, payload.incident_id))
      |> put_status("Acknowledged #{payload.incident_id}.", :info)
      |> append_log("[request] incident #{payload.incident_id} acknowledged")

    {:ok, next_state, []}
  end

  def handle_info({:append_log, line}, state, _props, _ctx) when is_binary(line) do
    {:ok, append_log(state, line), []}
  end

  def handle_info(_msg, _state, _props, _ctx), do: :unhandled

  @impl true
  def subscriptions(_state, _props, _ctx) do
    [
      Subscription.interval(:pulse, 750, :pulse),
      Subscription.interval(:auto_refresh, 4_000, :auto_refresh),
      Subscription.interval(:runtime_refresh, @runtime_refresh_ms, :runtime_refresh),
      Subscription.once(:boot_runtime_probe, 180, :runtime_refresh)
    ]
  end

  @impl true
  def keymap(_state, _props, _ctx) do
    [
      binding(:tab_left, "left", [], "Previous tab", :tab_left),
      binding(:tab_right, "right", [], "Next tab", :tab_right),
      binding(:select_prev, "up", [], "Select previous / scroll trace", :select_prev),
      binding(:select_next, "down", [], "Select next / scroll trace", :select_next),
      binding(:refresh, "r", [], "Refresh dashboard", :refresh),
      binding(:deploy, "d", [], "Deploy selected service", :deploy_selected),
      binding(:ack, "a", [], "Acknowledge selected incident", :ack_selected),
      binding(:runtime, "o", [], "Jump to runtime tab", :jump_runtime),
      binding(:snapshot, "s", [], "Request runtime snapshot", :snapshot_now),
      binding(:trace, "t", [], "Toggle runtime trace", :toggle_trace),
      binding(:probe, "x", [], "Run failing diagnostic", :run_failing_probe)
    ]
  end

  defp content_panel(%{active_tab: 3} = state, _props) do
    Node.hstack(
      :runtime_content,
      [
        WidgetList.new(
          id: :runtime_trace,
          title: "Runtime Trace",
          items: trace_widget_items(state),
          scroll_offset: state.trace_scroll_offset
        )
        |> Style.border_fg(:focus),
        Node.vstack(
          :runtime_sidebar,
          [
            Pane.new(
              id: :runtime_summary,
              title: "Runtime Snapshot",
              lines: runtime_summary_lines(state)
            )
            |> Style.border_fg(:success),
            Node.component(
              :control_loop_actor,
              ControlLoopActor,
              %{title: "Control Loop", label: "subscriptions + async requests"},
              mode: Workbench.Component.mode(ControlLoopActor)
            ),
            Detail.new(
              id: :subscriptions,
              title: "Subscriptions",
              lines: subscription_lines(state.runtime_snapshot)
            )
            |> Style.border_fg(:warning),
            Pane.new(
              id: :probe,
              title: "Last Probe",
              lines: state.last_probe_lines
            )
            |> Style.border_fg(status_tone(state.status_severity))
          ],
          constraints: [{:min, 7}, {:length, 3}, {:min, 7}, {:min, 6}]
        )
      ],
      constraints: [{:percentage, 66}, {:percentage, 34}]
    )
  end

  defp content_panel(state, props) do
    Node.hstack(
      :content,
      [
        main_panel(state),
        Node.vstack(
          :sidebar,
          [
            Pane.new(
              id: :summary,
              title: "Ops Snapshot",
              lines: summary_lines(state, props)
            )
            |> Style.border_fg(:success),
            ProgressBar.new(
              id: :cluster_health,
              title: "Cluster Health",
              ratio: state.cluster_health,
              label: percent_label(state.cluster_health)
            ),
            ProgressBar.new(
              id: :rollout,
              title: "Rollout Progress",
              ratio: state.rollout.percent,
              label: rollout_label(state.rollout)
            ),
            Node.component(
              :control_loop_actor,
              ControlLoopActor,
              %{title: "Control Loop", label: "subscriptions + async requests"},
              mode: Workbench.Component.mode(ControlLoopActor)
            ),
            Detail.new(
              id: :selection,
              title: "Selection",
              lines: selection_lines(state)
            )
            |> Style.border_fg(:warning),
            Pane.new(
              id: :activity,
              title: "Recent Activity",
              lines: recent_activity_lines(state)
            )
            |> Style.border_fg(:accent)
          ],
          constraints: [{:min, 7}, {:length, 3}, {:length, 3}, {:length, 3}, {:min, 8}, {:min, 6}]
        )
      ],
      constraints: [{:percentage, 58}, {:percentage, 42}]
    )
  end

  defp main_panel(%{active_tab: 0} = state) do
    Table.new(
      id: :services,
      title: "Services",
      header: ["Service", "Status", "Latency", "Ready"],
      rows:
        Enum.map(state.services, fn service ->
          [
            service.id,
            service_display_status(service, state.rollout),
            "#{service.latency_ms} ms",
            "#{service.ready_instances}/#{service.desired_instances}"
          ]
        end),
      widths: [{:percentage, 34}, {:percentage, 26}, {:percentage, 20}, {:percentage, 20}],
      selected: state.service_cursor
    )
    |> Style.border_fg(:warning)
    |> Style.highlight_fg(:focus)
  end

  defp main_panel(%{active_tab: 1} = state) do
    Table.new(
      id: :jobs,
      title: "Jobs",
      header: ["Job", "Status", "Progress", "Worker"],
      rows:
        Enum.map(state.jobs, fn job ->
          [job.id, job.status, "#{job.current}/#{job.total}", job.worker]
        end),
      widths: [{:percentage, 28}, {:percentage, 18}, {:percentage, 22}, {:percentage, 32}],
      selected: state.job_cursor
    )
    |> Style.border_fg(:warning)
    |> Style.highlight_fg(:focus)
  end

  defp main_panel(%{active_tab: 2} = state) do
    List.new(
      id: :incidents,
      title: "Incidents",
      items:
        Enum.map(state.incidents, fn incident ->
          incident_prefix(incident, state.acknowledged_incidents) <>
            incident.title <> "  ·  " <> incident.owner
        end),
      selected: state.incident_cursor
    )
    |> Style.border_fg(:warning)
    |> Style.highlight_fg(:focus)
  end

  defp summary_lines(state, props) do
    snapshot = Map.get(props, :snapshot, %{})

    [
      "refresh count: #{state.refresh_count}",
      "last refresh: #{state.last_refresh_at}",
      "queue depth: #{state.queue_depth}",
      "throughput: #{state.throughput_rps} rps",
      "recommended: #{state.recommended_action}",
      "snapshot: #{state.snapshot_summary} (#{length(Map.get(snapshot, :jobs, []))} local jobs)",
      "trace: #{if(state.trace_enabled, do: "on", else: "off")}  ·  runtime tab row-scrolls a WidgetList"
    ]
  end

  defp selection_lines(%{active_tab: 0} = state) do
    case selected_service(state) do
      nil ->
        ["No service selected."]

      service ->
        [
          "service: #{service.id}",
          "owner: #{service.owner}",
          "status: #{service_display_status(service, state.rollout)}",
          "latency: #{service.latency_ms} ms",
          "slo: #{service.slo}"
        ]
    end
  end

  defp selection_lines(%{active_tab: 1} = state) do
    case selected_job(state) do
      nil ->
        ["No job selected."]

      job ->
        [
          "job: #{job.id}",
          "title: #{job.title}",
          "status: #{job.status}",
          "progress: #{job.current}/#{job.total}",
          "worker: #{job.worker}"
        ]
    end
  end

  defp selection_lines(%{active_tab: 2} = state) do
    case selected_incident(state) do
      nil ->
        ["No incident selected."]

      incident ->
        [
          "incident: #{incident.id}",
          "severity: #{incident_display_state(incident, state.acknowledged_incidents)}",
          "owner: #{incident.owner}",
          "runbook: #{incident.runbook}",
          incident.summary
        ]
    end
  end

  defp recent_activity_lines(state) do
    state.logs
    |> Enum.take(-6)
    |> case do
      [] -> ["No activity yet."]
      lines -> lines
    end
  end

  defp runtime_summary_lines(state) do
    snapshot = state.runtime_snapshot
    {width, height} = snapshot.dimensions

    [
      "mode: #{snapshot.mode}",
      "transport: #{snapshot.transport}",
      "dimensions: #{width}x#{height}",
      "renders: #{snapshot.render_count}",
      "last render: #{format_timestamp_ms(snapshot.last_rendered_at)}",
      "subscriptions: #{snapshot.subscription_count}",
      "active async: #{snapshot.active_async_commands}",
      "trace: #{if(snapshot.trace_enabled?, do: "enabled", else: "disabled")} (limit #{snapshot.trace_limit})",
      "trace rows: #{state.trace_scroll_offset} scroll offset  ·  #{length(snapshot.trace_events)} retained events"
    ]
  end

  defp subscription_lines(%{subscriptions: []}) do
    [
      "No active subscriptions.",
      "The boot once-subscription should fall away after its first fire.",
      "Periodic runtime snapshot polling uses render?: false to avoid a redundant frame."
    ]
  end

  defp subscription_lines(snapshot) do
    snapshot.subscriptions
    |> Enum.map(fn subscription ->
      "#{subscription.id}: #{subscription.kind} #{subscription.interval_ms}ms active=#{subscription.active?} fired=#{subscription.fired?}"
    end)
    |> Enum.take(6)
  end

  defp help_lines(%{active_tab: 3}, %Context{} = ctx) do
    [
      "Up/Down row-scroll runtime trace  ·  Left/Right change tabs  ·  s snapshot  ·  t trace on/off",
      "x failing diagnostic  ·  Esc back  ·  Ctrl+Q quit"
    ] ++ debug_help_lines(ctx)
  end

  defp help_lines(_state, %Context{} = ctx) do
    [
      "Left/Right tabs  ·  Up/Down selection  ·  r refresh dashboard  ·  o runtime tab",
      "d deploy selected service  ·  a acknowledge selected incident  ·  s snapshot  ·  t trace  ·  x failing diagnostic  ·  Esc back  ·  Ctrl+Q quit"
    ] ++ debug_help_lines(ctx)
  end

  defp debug_help_lines(%Context{} = ctx) do
    if Map.get(ctx.devtools, :enabled?, false) do
      ["F12 toggle debug rail"]
    else
      []
    end
  end

  defp trace_widget_items(state) do
    state.runtime_snapshot.trace_events
    |> case do
      [] ->
        [
          {
            Pane.new(
              id: :trace_empty,
              title: "Trace Warming Up",
              lines: [
                "No trace events are retained yet.",
                "Press t to toggle trace capture and x to provoke a failing async probe.",
                "The runtime refresh subscription keeps sampling snapshot state without forcing a redundant render."
              ]
            )
            |> Style.border_fg(:focus),
            5
          }
        ]

      events ->
        Enum.map(Enum.with_index(events), fn {event, index} ->
          lines = trace_lines(event)

          {
            Pane.new(
              id: {:trace, index},
              title: trace_title(event, index),
              lines: lines
            )
            |> Style.border_fg(trace_border(event.kind)),
            length(lines) + 2
          }
        end)
    end
  end

  defp trace_lines(event) do
    details =
      event.details
      |> inspect(pretty: true, limit: 10, width: 54)
      |> String.split("\n")
      |> Enum.map(&String.trim_leading/1)

    ["at: #{format_timestamp_ms(event.at_ms)}" | details]
  end

  defp trace_title(event, index) do
    "##{index + 1}  ·  #{event.kind}"
  end

  defp trace_border(:command), do: :accent
  defp trace_border(:event), do: :warning
  defp trace_border(:render), do: :success
  defp trace_border(:subscription), do: :focus
  defp trace_border(_other), do: :surface_alt

  defp selected_service(state), do: Enum.at(state.services, state.service_cursor)
  defp selected_job(state), do: Enum.at(state.jobs, state.job_cursor)
  defp selected_incident(state), do: Enum.at(state.incidents, state.incident_cursor)

  defp move_cursor(%{active_tab: 0} = state, delta) do
    %{state | service_cursor: clamp_index(state.service_cursor + delta, state.services)}
  end

  defp move_cursor(%{active_tab: 1} = state, delta) do
    %{state | job_cursor: clamp_index(state.job_cursor + delta, state.jobs)}
  end

  defp move_cursor(%{active_tab: 2} = state, delta) do
    %{state | incident_cursor: clamp_index(state.incident_cursor + delta, state.incidents)}
  end

  defp move_cursor(state, _delta), do: state

  defp scroll_trace(state, delta, %Context{} = ctx) do
    next_offset =
      state.trace_scroll_offset
      |> Kernel.+(delta)
      |> max(0)
      |> min(max_trace_scroll_offset(state.runtime_snapshot, ctx))

    %{state | trace_scroll_offset: next_offset}
  end

  defp clamp_trace_scroll(snapshot, current_offset, %Context{} = ctx) do
    current_offset
    |> max(0)
    |> min(max_trace_scroll_offset(snapshot, ctx))
  end

  defp max_trace_scroll_offset(snapshot, %Context{} = ctx) do
    max(trace_total_rows(snapshot) - runtime_trace_viewport_rows(ctx), 0)
  end

  defp trace_total_rows(snapshot) do
    snapshot
    |> Map.get(:trace_events, [])
    |> case do
      [] ->
        5

      events ->
        events
        |> Enum.map(&(trace_lines(&1) |> length() |> Kernel.+(2)))
        |> Enum.sum()
    end
  end

  defp runtime_trace_viewport_rows(%Context{} = ctx) do
    max(ctx.screen.height - 12, 6)
  end

  defp advance_rollout(%{rollout: %{service_id: nil}} = state), do: state

  defp advance_rollout(%{rollout: rollout} = state) do
    next_percent = min(Float.round(rollout.percent + 0.07, 2), 1.0)

    next_rollout =
      if next_percent >= 1.0 do
        %{rollout | percent: 1.0, stage: "Stable"}
      else
        %{rollout | percent: next_percent}
      end

    %{state | rollout: next_rollout}
  end

  defp append_log(state, line) do
    %{state | logs: (state.logs ++ [line]) |> Enum.take(-18)}
  end

  defp runtime_snapshot_command(server_pid) do
    Cmd.async(fn -> ExRatatui.Runtime.snapshot(server_pid) end, &{:runtime_snapshot_ready, &1})
  end

  defp trace_toggle_command(server_pid, enabled?) do
    Cmd.async(
      fn ->
        if enabled? do
          ExRatatui.Runtime.enable_trace(server_pid)
        else
          ExRatatui.Runtime.disable_trace(server_pid)
        end
      end,
      fn :ok -> {:trace_toggle_applied, enabled?} end
    )
  end

  defp failing_probe_command do
    Cmd.async(
      fn -> raise "simulated diagnostic failure" end,
      &{:diagnostic_probe_finished, &1}
    )
  end

  defp dashboard_request(refresh_count) do
    Cmd.request({:refresh_dashboard, refresh_count}, [], &{:dashboard_loaded, &1})
  end

  defp summarize_snapshot(snapshot) do
    process_count = snapshot |> Map.get(:processes, []) |> length()
    job_count = snapshot |> Map.get(:jobs, []) |> length()
    runbook_count = snapshot |> Map.get(:runbooks, []) |> length()
    incident_count = snapshot |> Map.get(:incidents, []) |> length()

    "#{process_count} processes, #{job_count} jobs, #{runbook_count} runbooks, #{incident_count} incidents"
  end

  defp diagnostic_failure_lines({:exception, reason}) when is_binary(reason) do
    [
      "result: exception",
      "reason: #{reason}",
      "The reducer runtime normalized the failure and drained active async back to zero."
    ]
  end

  defp diagnostic_failure_lines({:exit, reason}) do
    [
      "result: exit",
      "reason: #{inspect(reason)}",
      "The async task exited and still returned a structured reducer message."
    ]
  end

  defp diagnostic_failure_lines({:throw, reason}) do
    [
      "result: throw",
      "reason: #{inspect(reason)}",
      "Thrown values are normalized too."
    ]
  end

  defp diagnostic_failure_lines(other) do
    [
      "result: failure",
      "reason: #{inspect(other)}",
      "The probe intentionally exercises the async failure path."
    ]
  end

  defp empty_runtime_snapshot(trace_enabled?) do
    %{
      mode: :reducer,
      transport: :local,
      polling_enabled?: false,
      dimensions: {0, 0},
      render_count: 0,
      last_rendered_at: nil,
      trace_enabled?: trace_enabled?,
      trace_limit: 200,
      trace_events: [],
      subscription_count: 0,
      subscriptions: [],
      active_async_commands: 0
    }
  end

  defp percent_label(ratio), do: "#{round(ratio * 100)}%"

  defp rollout_label(%{service_id: nil}), do: "idle"

  defp rollout_label(%{service_id: service_id, stage: stage, percent: percent}) do
    "#{service_id}  ·  #{stage}  ·  #{round(percent * 100)}%"
  end

  defp service_display_status(service, %{service_id: service_id, stage: stage})
       when service.id == service_id,
       do: String.downcase(stage)

  defp service_display_status(service, _rollout), do: service.status

  defp incident_display_state(incident, acknowledged_incidents) do
    if MapSet.member?(acknowledged_incidents, incident.id),
      do: "acknowledged",
      else: Atom.to_string(incident.severity)
  end

  defp incident_prefix(incident, acknowledged_incidents) do
    if MapSet.member?(acknowledged_incidents, incident.id) do
      "[acked] "
    else
      "[#{incident.severity}] "
    end
  end

  defp put_status(state, line, severity) do
    %{state | status_line: line, status_severity: severity}
  end

  defp status_tone(:error), do: :danger
  defp status_tone(:warn), do: :warning
  defp status_tone(_severity), do: :success

  defp clamp_index(_index, []), do: 0
  defp clamp_index(index, items), do: index |> max(0) |> min(length(items) - 1)

  defp format_datetime(datetime), do: Calendar.strftime(datetime, "%H:%M:%SZ")

  defp format_timestamp_ms(nil), do: "not yet"

  defp format_timestamp_ms(ms) when is_integer(ms) do
    ms
    |> DateTime.from_unix!(:millisecond)
    |> Calendar.strftime("%H:%M:%S.%fZ")
    |> String.replace_suffix("000Z", "Z")
  end

  defp binding(id, code, modifiers, description, message) do
    Keymap.binding(
      id: id,
      keys: [Keymap.key(code, modifiers)],
      description: description,
      message: message
    )
  end
end

defmodule Switchyard.Examples.FullFeatured.Runner do
  @moduledoc false

  alias ExRatatui.{Distributed, Event, Runtime}
  alias Switchyard.Examples.FullFeatured.{Data, DemoSite}
  alias Switchyard.Site.Local
  alias Switchyard.TUI
  alias Switchyard.TUI.App
  alias Workbench.Devtools.Driver

  def main(argv) do
    {opts, _args, _invalid} =
      OptionParser.parse(argv,
        strict: [
          describe: :boolean,
          smoke: :boolean,
          distributed_smoke: :boolean,
          distributed: :boolean,
          attach: :string,
          open_app: :string,
          debug: :boolean,
          debug_dir: :string
        ]
      )

    debug_opts =
      opts
      |> Keyword.take([:debug, :debug_dir])
      |> Enum.filter(fn
        {:debug, true} -> true
        {_key, value} -> not is_nil(value)
      end)

    cond do
      Keyword.get(opts, :describe, false) ->
        describe()

      Keyword.get(opts, :smoke, false) ->
        smoke(Keyword.get(opts, :open_app), debug_opts)

      Keyword.get(opts, :distributed_smoke, false) ->
        distributed_smoke(Keyword.get(opts, :open_app), debug_opts)

      Keyword.get(opts, :distributed, false) ->
        run_distributed(Keyword.get(opts, :open_app), debug_opts)

      node_name = Keyword.get(opts, :attach) ->
        attach(node_name)

      true ->
        interactive(Keyword.get(opts, :open_app), debug_opts)
    end
  end

  defp interactive(open_app, debug_opts) do
    TUI.run(base_opts(normalize_open_app(open_app), debug_opts))
  end

  defp smoke(open_app, debug_opts) do
    app_id = normalize_open_app(open_app) || "fleet_demo.control_room"

    {:ok, pid} =
      App.start_link(
        base_opts(app_id, debug_opts)
        |> Keyword.put(:test_mode, {110, 32})
      )

    ref = Process.monitor(pid)

    initial_snapshot =
      Driver.wait_for_snapshot!(pid, "local smoke startup", fn snapshot ->
        not snapshot.polling_enabled? and
          snapshot.render_count >= 1 and
          snapshot.subscription_count >= 5 and
          snapshot.active_async_commands == 0 and
          snapshot_has_message?(snapshot, &match?({:dashboard_loaded, _}, &1)) and
          snapshot_has_message?(snapshot, &match?({:snapshot_summary_ready, _}, &1)) and
          snapshot_has_message?(snapshot, &match?({:runtime_snapshot_ready, _}, &1)) and
          snapshot_has_message?(snapshot, &match?({:mounted_actor_ready, _}, &1))
      end)

    if initial_snapshot.polling_enabled? do
      raise "smoke mode should be headless under test_mode"
    end

    Driver.inject_key(pid, "r")
    Driver.inject_key(pid, "d")
    Driver.inject_key(pid, "right")
    Driver.inject_key(pid, "down")
    Driver.inject_key(pid, "right")
    Driver.inject_key(pid, "a")
    Driver.inject_key(pid, "o")
    Driver.inject_key(pid, "down")
    Driver.inject_key(pid, "s")
    Driver.inject_key(pid, "x")

    pre_resize_snapshot =
      Driver.wait_for_snapshot!(pid, "local smoke actions", fn snapshot ->
        snapshot.active_async_commands == 0 and
          snapshot.render_count > initial_snapshot.render_count and
          snapshot_has_message?(snapshot, &match?({:deploy_started, _}, &1)) and
          snapshot_has_message?(snapshot, &match?({:incident_acknowledged, _}, &1)) and
          snapshot_has_message?(snapshot, &match?({:runtime_snapshot_ready, _}, &1)) and
          snapshot_has_message?(snapshot, &match?({:mounted_actor_tick, _}, &1)) and
          snapshot_has_message?(snapshot, &match?({:diagnostic_probe_finished, {:error, _}}, &1)) and
          snapshot_has_event?(snapshot, &match?(%Event.Key{code: "x"}, &1))
      end)

    Driver.inject_resize(pid, 120, 36)

    snapshot =
      Driver.wait_for_snapshot!(pid, "local smoke resize", fn snapshot ->
        snapshot.render_count > pre_resize_snapshot.render_count and
          snapshot_has_event?(snapshot, &match?(%Event.Resize{width: 120, height: 36}, &1))
      end)

    cond do
      snapshot.render_count < 8 ->
        raise "smoke mode did not render enough frames to prove runtime activity"

      snapshot.subscription_count < 3 ->
        raise "smoke mode did not retain the expected subscription set"

      snapshot.active_async_commands != 0 ->
        raise "smoke mode left async commands in flight"

      snapshot.trace_events == [] ->
        raise "smoke mode did not retain runtime trace events"

      snapshot.render_count <= pre_resize_snapshot.render_count ->
        raise "smoke mode did not observe the injected resize event"

      true ->
        :ok
    end

    Driver.inject_key(pid, "q", ["ctrl"])

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} ->
        IO.puts(
          "smoke ok: renders=#{snapshot.render_count} subscriptions=#{snapshot.subscription_count} trace=#{length(snapshot.trace_events)} active_async=#{snapshot.active_async_commands} size=#{format_dimensions(snapshot.dimensions)}"
        )
    after
      5_000 ->
        raise "smoke mode timed out waiting for the TUI to stop"
    end
  end

  defp run_distributed(open_app, debug_opts) do
    ensure_distributed!("--distributed")

    {:ok, pid} =
      App.start_link(distributed_opts(normalize_open_app(open_app), debug_opts))

    IO.puts("""

    Switchyard full-featured example over Erlang distribution

    This node: #{Node.self()}

    From another node with the same cookie, run:

        elixir --sname operator --cookie #{Node.get_cookie()} examples/full_featured_workbench.exs --attach #{Node.self()}

    Press Ctrl-C twice to stop the listener.
    """)

    wait_for(pid)
  end

  defp distributed_smoke(open_app, debug_opts) do
    ensure_distributed!("--distributed-smoke")

    app_id = normalize_open_app(open_app) || "fleet_demo.control_room"

    {:ok, listener} =
      App.start_link(distributed_opts(app_id, debug_opts))

    try do
      {:ok, pid} = ExRatatui.Distributed.Listener.start_session(self(), 110, 32, listener)
      ref = Process.monitor(pid)

      expect_draw!("initial distributed draw")
      :ok = Runtime.enable_trace(pid)

      startup_snapshot =
        Driver.wait_for_snapshot!(pid, "distributed smoke startup", fn snapshot ->
          snapshot.transport == :distributed_server and
            snapshot.render_count >= 1 and
            snapshot.trace_enabled?
        end)

      Driver.inject_key(pid, "o")
      Driver.inject_key(pid, "right")

      pre_resize_snapshot =
        Driver.wait_for_snapshot!(pid, "distributed smoke actions", fn snapshot ->
          snapshot.active_async_commands == 0 and
            snapshot.render_count >= startup_snapshot.render_count + 2 and
            snapshot_has_event?(snapshot, &match?(%Event.Key{code: "o"}, &1)) and
            snapshot_has_event?(snapshot, &match?(%Event.Key{code: "right"}, &1))
        end)

      Driver.inject_resize(pid, 120, 36)

      snapshot =
        Driver.wait_for_snapshot!(pid, "distributed smoke resize", fn snapshot ->
          snapshot.dimensions == {120, 36} and
            snapshot.render_count > pre_resize_snapshot.render_count
        end)

      cond do
        snapshot.transport != :distributed_server ->
          raise "distributed smoke did not start a distributed_server session"

        snapshot.render_count < 4 ->
          raise "distributed smoke did not render enough frames"

        snapshot.trace_events == [] ->
          raise "distributed smoke did not retain runtime trace events"

        snapshot.dimensions != {120, 36} ->
          raise "distributed smoke did not apply the distributed resize path"

        true ->
          :ok
      end

      Driver.inject_key(pid, "q", ["ctrl"])

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} ->
          IO.puts(
            "distributed smoke ok: renders=#{snapshot.render_count} subscriptions=#{snapshot.subscription_count} trace=#{length(snapshot.trace_events)} size=#{format_dimensions(snapshot.dimensions)}"
          )
      after
        5_000 ->
          raise "distributed smoke timed out waiting for the session to stop"
      end
    after
      GenServer.stop(listener)
    end
  end

  defp attach(node_name) do
    ensure_distributed!("--attach")

    case Distributed.attach(normalize_node(node_name), App) do
      :ok ->
        :ok

      {:error, reason} ->
        raise "distributed attach failed: #{inspect(reason)}"
    end
  end

  defp describe do
    IO.puts("""
    Switchyard full-featured example

    Sites
    - Fleet Demo: custom Control Room component plus generic Runbooks and Incidents apps
    - Local: built-in Processes and Jobs list/detail views

    Control Room features
    - provider-driven site and app catalog
    - custom Workbench component rendered through Switchyard.TUI
    - mounted supervised child actor proving runtime-owned widget lifecycle and subscriptions
    - Workbench request, async, timer, batch, and subscription commands
    - reducer runtime observability: snapshot polling, trace toggles, and a controlled async failure probe
    - quiet runtime refreshes that use render?: false before the async snapshot result paints
    - ex_ratatui widgets via the Workbench renderer: tabs, table, list, pane, detail, throbber, gauge, status bar, WidgetList
    - runtime tab with row-based variable-height WidgetList scrolling over retained trace events
    - distributed listener and attach flow through the same app module

    Run commands
    - elixir examples/full_featured_workbench.exs
    - elixir examples/full_featured_workbench.exs --open-app control-room
    - elixir examples/full_featured_workbench.exs --smoke
    - elixir examples/full_featured_workbench.exs --debug
    - elixir --sname switchyard_smoke --cookie demo examples/full_featured_workbench.exs --distributed-smoke
    - elixir --sname switchyard_demo --cookie demo examples/full_featured_workbench.exs --distributed
    - elixir --sname operator --cookie demo examples/full_featured_workbench.exs --attach switchyard_demo@YOUR_HOST
    """)
  end

  defp base_opts(open_app, debug_opts) do
    [
      name: nil,
      site_modules: [DemoSite, Local],
      snapshot: Data.base_snapshot(),
      request_handler: &request_handler/2,
      initial_trace?: true
    ]
    |> maybe_put_open_app(open_app)
    |> Keyword.merge(debug_opts)
  end

  defp distributed_opts(open_app, debug_opts) do
    base_opts(open_app, debug_opts)
    |> Keyword.delete(:name)
    |> Keyword.put(:transport, :distributed)
  end

  defp maybe_put_open_app(opts, nil), do: opts
  defp maybe_put_open_app(opts, open_app), do: Keyword.put(opts, :open_app, open_app)

  defp request_handler({:refresh_dashboard, refresh_count}, _opts) do
    Data.dashboard_payload(refresh_count)
  end

  defp request_handler({:deploy_service, service_id, refresh_count}, _opts) do
    Data.deploy_payload(service_id, refresh_count)
  end

  defp request_handler({:ack_incident, incident_id}, _opts) do
    Data.ack_payload(incident_id)
  end

  defp request_handler(request, _opts), do: {:error, {:unsupported_request, request}}

  defp normalize_open_app(nil), do: nil

  defp normalize_open_app("control-room"), do: "fleet_demo.control_room"
  defp normalize_open_app("runbooks"), do: "fleet_demo.runbooks"
  defp normalize_open_app("incidents"), do: "fleet_demo.incidents"
  defp normalize_open_app("local-processes"), do: "local.processes"
  defp normalize_open_app(open_app), do: open_app

  defp ensure_distributed!(mode) do
    if Node.alive?() do
      :ok
    else
      IO.puts(:stderr, """

      Error: #{mode} requires a distributed local node.
      Start the example with --sname or --name, for example:

          elixir --sname switchyard_demo --cookie demo examples/full_featured_workbench.exs #{mode}
      """)

      System.halt(1)
    end
  end

  defp wait_for(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    end
  end

  defp normalize_node(node_name) do
    node_name
    |> String.trim()
    |> String.to_atom()
  end

  defp format_dimensions({width, height}), do: "#{width}x#{height}"

  defp expect_draw!(label) do
    receive do
      {:ex_ratatui_draw, _widgets} -> :ok
    after
      2_000 -> raise "#{label} never arrived"
    end
  end

  defp snapshot_has_message?(snapshot, matcher) when is_function(matcher, 1) do
    Enum.any?(snapshot.trace_events, fn
      %{kind: :message, details: %{payload: payload}} -> matcher.(payload)
      _other -> false
    end)
  end

  defp snapshot_has_event?(snapshot, matcher) when is_function(matcher, 1) do
    Enum.any?(snapshot.trace_events, fn
      %{kind: :message, details: %{source: :event, payload: payload}} -> matcher.(payload)
      _other -> false
    end)
  end
end

Switchyard.Examples.FullFeatured.Runner.main(System.argv())
