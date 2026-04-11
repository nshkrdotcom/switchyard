defmodule Switchyard.TUI.ControllerTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Command
  alias ExRatatui.Event
  alias Switchyard.Contracts.{AppDescriptor, Resource, ResourceDetail, SiteDescriptor}
  alias Switchyard.TUI.{Controller, Model, Mount}

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

  defmodule ExampleMount do
    @behaviour Mount

    @impl true
    def id, do: "example.mounted"

    @impl true
    def init(_opts), do: %{opened?: false, messages: []}

    @impl true
    def open(model, state) do
      next_state = %{state | opened?: true}

      command =
        Command.async(
          fn -> :mounted_loaded end,
          fn :mounted_loaded -> {:mount_ready, "mounted"} end
        )

      {Model.set_status(model, "Opening mounted workspace...", :info), next_state, [command]}
    end

    @impl true
    def event_to_msg(%Event.Key{code: "x", modifiers: []}, _model, _state),
      do: {:msg, :mount_ping}

    def event_to_msg(%Event.Key{}, _model, _state), do: :ignore

    @impl true
    def update(:mount_ping, model, state) do
      {Model.set_status(model, "Mounted ping received.", :info),
       %{state | messages: [:mount_ping | state.messages]}, []}
    end

    def update({:mount_ready, "mounted"}, model, state) do
      {Model.set_status(model, "Mounted workspace ready.", :info), state, []}
    end

    def update(_msg, _model, _state), do: :unhandled

    @impl true
    def render(_model, _frame, _state), do: []
  end

  defp base_state do
    Model.new(
      sites: [
        %{id: "local", title: "Local"},
        %{id: "example", title: "Example"}
      ],
      apps: ExampleSite.apps(),
      mount_modules: %{ExampleMount.id() => ExampleMount},
      mount_states: %{ExampleMount.id() => ExampleMount.init([])},
      home_cursor: 1
    )
  end

  test "enter on the home screen opens the selected site's app list" do
    {next_state, commands} = Controller.update(:enter, base_state())

    assert commands == []
    assert next_state.shell.route == :site_apps
    assert next_state.shell.selected_site_id == "example"
    assert next_state.site_app_cursor == 0
  end

  test "enter on a mounted app opens the generic app route and runs mount open" do
    state =
      base_state()
      |> Map.put(:shell, %{base_state().shell | route: :site_apps, selected_site_id: "example"})

    {next_state, commands} = Controller.update(:enter, state)

    assert next_state.shell.route == :app
    assert next_state.shell.selected_app_id == "example.mounted"
    assert next_state.status_line == "Opening mounted workspace..."
    assert next_state.mount_states["example.mounted"].opened?
    assert [%Command{kind: :async}] = Command.normalize(commands)
  end

  test "mounted app messages are delegated to the active mount module" do
    state =
      base_state()
      |> Map.put(:shell, %{base_state().shell | route: :app, selected_app_id: "example.mounted"})

    {next_state, commands} = Controller.update(:mount_ping, state)

    assert commands == []
    assert next_state.status_line == "Mounted ping received."
    assert next_state.mount_states["example.mounted"].messages == [:mount_ping]
  end

  test "generic apps use host resource navigation" do
    state =
      base_state()
      |> Map.put(:shell, %{base_state().shell | route: :app, selected_app_id: "example.resources"})
      |> Map.put(:resource_cursor, 0)

    {next_state, commands} = Controller.update(:select_next, state)

    assert commands == []
    assert next_state.resource_cursor == 0
  end

  test "event_to_msg delegates to the active mount before using the default keymap" do
    state =
      base_state()
      |> Map.put(:shell, %{base_state().shell | route: :app, selected_app_id: "example.mounted"})

    assert {:msg, :mount_ping} =
             Controller.event_to_msg(%Event.Key{code: "x", modifiers: []}, state)
  end
end
