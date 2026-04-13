defmodule Switchyard.TUI.RootTest do
  use ExUnit.Case, async: true

  alias Switchyard.Contracts.{AppDescriptor, Resource, ResourceDetail, SiteDescriptor}
  alias Switchyard.TUI.{Root, State}
  alias Workbench.{Context, Node}
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

  test "enter on the home screen opens the selected site's app list" do
    assert {:ok, next_state, commands} =
             Root.update(:enter, base_state(), %{}, %Context{app_env: %{}})

    assert commands == []
    assert next_state.shell.route == :site_apps
    assert next_state.shell.selected_site_id == "example"
    assert next_state.site_app_cursor == 0
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
end
