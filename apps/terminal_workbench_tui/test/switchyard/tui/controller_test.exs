defmodule Switchyard.TUI.RootTest do
  use ExUnit.Case, async: true

  alias Switchyard.Contracts.{Action, AppDescriptor, Resource, ResourceDetail, SiteDescriptor}
  alias Switchyard.TUI.{Root, State}
  alias Workbench.{Cmd, Context, Node}
  alias Workbench.Widgets.Pane

  defmodule ExampleSite do
    @behaviour Switchyard.Contracts.SiteProvider

    @impl true
    def site_definition do
      SiteDescriptor.new!(%{
        id: "example",
        title: "Example",
        provider: __MODULE__,
        kind: :remote,
        capabilities: [:apps, :resources]
      })
    end

    @impl true
    def apps do
      [
        AppDescriptor.new!(%{
          id: "example.mounted",
          site_id: "example",
          title: "Mounted Workspace",
          provider: __MODULE__,
          resource_kinds: [:workspace],
          route_kind: :workspace
        }),
        AppDescriptor.new!(%{
          id: "example.resources",
          site_id: "example",
          title: "Resources",
          provider: __MODULE__,
          resource_kinds: [:note],
          route_kind: :list_detail
        })
      ]
    end

    @impl true
    def actions, do: []

    @impl true
    def resources(_snapshot) do
      [
        Resource.new!(%{
          site_id: "example",
          kind: :note,
          id: "note-1",
          title: "First note",
          subtitle: "ready",
          status: :ready,
          summary: "example summary"
        })
      ]
    end

    @impl true
    def detail(resource, _snapshot) do
      ResourceDetail.new!(%{
        resource: resource,
        sections: [%{title: "Detail", lines: ["id: #{resource.id}"]}],
        recommended_actions: ["Inspect"]
      })
    end
  end

  defmodule ExampleComponent do
    @behaviour Workbench.Component

    @impl true
    def init(_props, _ctx) do
      command =
        Workbench.Cmd.async(
          fn -> :mounted_loaded end,
          fn :mounted_loaded -> {:mount_ready, "mounted"} end
        )

      {:ok, %{opened?: true, messages: []}, [command]}
    end

    @impl true
    def update({:key, %ExRatatui.Event.Key{code: "x", modifiers: []}}, state, _props, _ctx) do
      {:ok, %{state | messages: [:mount_ping | state.messages]}, []}
    end

    def update(_msg, _state, _props, _ctx), do: :unhandled

    @impl true
    def render(_state, _props, _ctx),
      do: Pane.new(id: :mounted, title: "Mounted", lines: ["ready"])

    @impl true
    def handle_info({:mount_ready, "mounted"}, state, _props, _ctx), do: {:ok, state, []}

    def handle_info(_msg, _state, _props, _ctx), do: :unhandled
  end

  defmodule ProcessSite do
    @behaviour Switchyard.Contracts.SiteProvider

    @impl true
    def site_definition do
      SiteDescriptor.new!(%{
        id: "execution_plane",
        title: "Execution Plane",
        provider: __MODULE__,
        kind: :local
      })
    end

    @impl true
    def apps do
      [
        AppDescriptor.new!(%{
          id: "execution_plane.processes",
          site_id: "execution_plane",
          title: "Processes",
          provider: __MODULE__,
          resource_kinds: [:process],
          route_kind: :list_detail
        })
      ]
    end

    @impl true
    def actions do
      [
        Action.new!(%{
          id: "execution_plane.process.stop",
          title: "Stop process",
          scope: {:resource, :process},
          provider: __MODULE__,
          confirmation: :if_destructive
        }),
        Action.new!(%{
          id: "execution_plane.process.signal",
          title: "Signal process",
          scope: {:resource, :process},
          provider: __MODULE__,
          input_schema: %{
            "type" => "object",
            "properties" => %{
              "signal" => %{"type" => "string", "default" => "TERM"}
            }
          }
        })
      ]
    end

    @impl true
    def resources(_snapshot) do
      [
        Resource.new!(%{
          site_id: "execution_plane",
          kind: :process,
          id: "proc-1",
          title: "Process proc-1",
          subtitle: "running",
          status: :running,
          summary: "sleep 5"
        })
      ]
    end

    @impl true
    def detail(resource, _snapshot) do
      ResourceDetail.new!(%{
        resource: resource,
        sections: [
          %{title: "Process", lines: ["id: #{resource.id}", "stream: logs/#{resource.id}"]}
        ],
        recommended_actions: []
      })
    end
  end

  defp base_state do
    State.new(
      sites: [
        %{id: "local", title: "Local"},
        %{id: "example", title: "Example"}
      ],
      apps: ExampleSite.apps(),
      home_cursor: 1
    )
  end

  defp process_state do
    state = State.new().shell

    State.new(
      sites: [%{id: "execution_plane", title: "Execution Plane"}],
      apps: ProcessSite.apps(),
      snapshot: %{processes: [%{id: "proc-1"}], jobs: [], streams: []},
      shell: %{
        state
        | route: :app,
          selected_site_id: "execution_plane",
          selected_app_id: "execution_plane.processes"
      }
    )
  end

  test "enter on the home screen opens the selected site's app list" do
    assert {:ok, next_state, commands} =
             Root.update(:enter, base_state(), %{}, %Context{app_env: %{}})

    assert commands == []
    assert next_state.shell.route == :site_apps
    assert next_state.shell.selected_site_id == "example"
    assert next_state.site_app_cursor == 0
  end

  test "init requests an initial snapshot when a request handler is configured" do
    assert {:ok, _state, [%Cmd{kind: :request, payload: {:local_snapshot, [], mapper}}]} =
             Root.init(%{}, %Context{request_handler: fn _request, _opts -> :ok end, app_env: %{}})

    assert mapper.(%{processes: [], jobs: []}) == {:snapshot_loaded, %{processes: [], jobs: []}}
  end

  test "home route emits normalized node styles and layout padding" do
    assert %Node{layout: %{padding: {1, 1, 0, 0}}, children: [header, sites, help, status]} =
             Root.render(base_state(), %{}, %Context{app_env: %{}})

    assert header.style[:border_fg] == :accent
    refute Map.has_key?(header.props, :border_fg)

    assert sites.style[:border_fg] == :warning
    assert sites.style[:highlight_fg] == :focus

    assert help.style[:border_fg] == :muted
    assert status.style[:fg] == :success
  end

  test "quit requests a reducer stop instead of an unsupported command" do
    assert {:stop, %State{}} = Root.update(:quit, base_state(), %{}, %Context{app_env: %{}})
  end

  test "enter on a custom component app opens the app route without root-owned component state" do
    state =
      base_state()
      |> Map.put(:apps, [
        AppDescriptor.new!(%{
          id: "example.mounted",
          site_id: "example",
          title: "Mounted Workspace",
          provider: ExampleSite,
          resource_kinds: [:workspace],
          route_kind: :workspace,
          tui_component: ExampleComponent
        })
      ])
      |> Map.put(:shell, %{base_state().shell | route: :site_apps, selected_site_id: "example"})

    assert {:ok, next_state, commands} =
             Root.update(:enter, state, %{}, %Context{app_env: %{}})

    assert next_state.shell.route == :app
    assert next_state.shell.selected_app_id == "example.mounted"
    assert next_state.status_line == "Opened example.mounted."
    assert commands == []
  end

  test "custom app route renders a component mount node" do
    state =
      base_state()
      |> Map.put(:apps, [
        AppDescriptor.new!(%{
          id: "example.mounted",
          site_id: "example",
          title: "Mounted Workspace",
          provider: ExampleSite,
          resource_kinds: [:workspace],
          route_kind: :workspace,
          tui_component: ExampleComponent
        })
      ])
      |> Map.put(:shell, %{base_state().shell | route: :app, selected_app_id: "example.mounted"})

    assert %Node{kind: :component, id: :active_app, module: ExampleComponent} =
             Root.render(state, %{}, %Context{app_env: %{}})
  end

  test "custom app route still exposes esc back through the root shell keymap" do
    state =
      base_state()
      |> Map.put(:apps, [
        AppDescriptor.new!(%{
          id: "example.mounted",
          site_id: "example",
          title: "Mounted Workspace",
          provider: ExampleSite,
          resource_kinds: [:workspace],
          route_kind: :workspace,
          tui_component: ExampleComponent
        })
      ])
      |> Map.put(:shell, %{base_state().shell | route: :app, selected_app_id: "example.mounted"})

    bindings = Root.keymap(state, %{}, %Context{app_env: %{}})

    assert Enum.any?(bindings, fn binding ->
             binding.message == :back and %{code: "esc", modifiers: []} in binding.keys
           end)
  end

  test "custom app key events are unhandled by the root when runtime-managed" do
    state =
      base_state()
      |> Map.put(:apps, [
        AppDescriptor.new!(%{
          id: "example.mounted",
          site_id: "example",
          title: "Mounted Workspace",
          provider: ExampleSite,
          resource_kinds: [:workspace],
          route_kind: :workspace,
          tui_component: ExampleComponent
        })
      ])
      |> Map.put(:shell, %{base_state().shell | route: :app, selected_app_id: "example.mounted"})

    assert :unhandled ==
             Root.update(
               {:key, %ExRatatui.Event.Key{code: "x", modifiers: []}},
               state,
               %{},
               %Context{app_env: %{}}
             )
  end

  test "generic apps use host resource navigation" do
    state =
      base_state()
      |> Map.put(:shell, %{base_state().shell | route: :app, selected_app_id: "example.resources"})
      |> Map.put(:resource_cursor, 0)

    assert {:ok, next_state, commands} =
             Root.update(:select_next, state, %{}, %Context{app_env: %{}})

    assert commands == []
    assert next_state.resource_cursor == 0
  end

  test "generic app route exposes refresh and local process actions" do
    state =
      base_state()
      |> Map.put(:apps, [
        AppDescriptor.new!(%{
          id: "execution_plane.processes",
          site_id: "execution_plane",
          title: "Processes",
          provider: ExampleSite,
          resource_kinds: [:note],
          route_kind: :list_detail
        })
      ])
      |> Map.put(:shell, %{
        base_state().shell
        | route: :app,
          selected_app_id: "execution_plane.processes"
      })

    bindings = Root.keymap(state, %{}, %Context{app_env: %{}})

    assert Enum.any?(bindings, &(&1.message == :refresh_snapshot))
    assert Enum.any?(bindings, &(&1.message == :start_demo_process))
  end

  test "generic process route requests and renders recent log preview through request path" do
    ctx = %Context{request_handler: fn _request, _opts -> :ok end, app_env: %{}}

    assert {:ok, loading_state,
            [%Cmd{kind: :request, payload: {{:logs, "logs/proc-1", [tail: 5]}, [], mapper}}]} =
             Root.update(:load_selected_logs, process_state(), %{}, ctx)

    assert loading_state.status_line == "Loading recent logs..."

    events = [%{fields: %{seq: 1}, level: :info, message: "hello"}]
    assert mapper.(events) == {:logs_loaded, "logs/proc-1", events}

    assert {:ok, loaded_state, []} =
             Root.handle_info({:logs_loaded, "logs/proc-1", events}, process_state(), %{}, ctx)

    assert loaded_state.log_previews["logs/proc-1"] == events

    rendered = Root.render(loaded_state, %{}, ctx)
    lines = node_lines(rendered)

    assert "Recent Logs" in lines
    assert "  #1 info: hello" in lines

    bindings = Root.keymap(loaded_state, %{}, ctx)
    assert Enum.any?(bindings, &(&1.message == :load_selected_logs))
  end

  test "generic process route renders resource action list" do
    rendered = Root.render(process_state(), %{}, %Context{app_env: %{}})
    lines = node_lines(rendered)

    assert "Available Actions" in lines
    assert "  > Stop process" in lines
    assert "    Signal process" in lines
  end

  test "generic process route keeps action form state in the product reducer" do
    assert {:ok, next_state, []} =
             Root.update(
               {:set_action_input, "execution_plane.process.signal", "signal", "HUP"},
               process_state(),
               %{},
               %Context{app_env: %{}}
             )

    assert next_state.action_form["execution_plane.process.signal"] == %{"signal" => "HUP"}
  end

  test "generic process route confirms destructive actions through request handler commands" do
    ctx = %Context{request_handler: fn _request, _opts -> :ok end, app_env: %{}}

    assert {:ok, confirming_state, []} =
             Root.update(:run_selected_action, process_state(), %{}, ctx)

    assert confirming_state.status_line == "Confirm action: Stop process."
    assert confirming_state.confirming_action.id == "execution_plane.process.stop"

    assert {:ok, submitted_state,
            [
              %Cmd{
                kind: :request,
                payload:
                  {%{
                     kind: :execute_action,
                     action_id: "execution_plane.process.stop",
                     resource: %{site_id: "execution_plane", kind: :process, id: "proc-1"},
                     input: %{},
                     confirmed?: true
                   }, [], mapper}
              }
            ]} = Root.update(:confirm_action, confirming_state, %{}, ctx)

    assert submitted_state.confirming_action == nil
    result = {:ok, %{status: :accepted, message: "process stopped"}}
    assert mapper.(result) == {:action_completed, result}

    assert {:ok, completed_state, []} =
             Root.handle_info({:action_completed, result}, submitted_state, %{}, ctx)

    assert completed_state.last_action_result == result
    assert completed_state.status_line == "Action completed: process stopped"
  end

  test "handle_info updates snapshot state after a refresh" do
    snapshot = %{processes: [%{id: "echo"}], jobs: []}

    assert {:ok, next_state, []} =
             Root.handle_info(
               {:snapshot_loaded, snapshot},
               base_state(),
               %{},
               %Context{app_env: %{}}
             )

    assert next_state.snapshot == snapshot
    assert next_state.status_line == "Snapshot refreshed."
  end

  test "handle_info surfaces degraded recovery status after a refresh" do
    snapshot = %{
      processes: [],
      jobs: [],
      recovery_status: %{status: :degraded, warnings: ["process proc-1 marked lost"]}
    }

    assert {:ok, next_state, []} =
             Root.handle_info(
               {:snapshot_loaded, snapshot},
               base_state(),
               %{},
               %Context{app_env: %{}}
             )

    assert next_state.snapshot == snapshot
    assert next_state.status_line == "Recovery warning: process proc-1 marked lost"
    assert next_state.status_severity == :warn
  end

  defp node_lines(%Node{props: props, children: children}) do
    Map.get(props, :lines, []) ++ Enum.flat_map(children, &node_lines/1)
  end

  defp node_lines(_other), do: []
end
