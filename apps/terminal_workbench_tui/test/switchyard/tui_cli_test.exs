defmodule Switchyard.TUICLITest do
  use ExUnit.Case, async: true

  alias ExRatatui.Command
  alias Switchyard.Contracts.{AppDescriptor, SiteDescriptor}
  alias Switchyard.TUI.App
  alias Switchyard.TUI.CLI
  alias Switchyard.TUI.EscriptBootstrap
  alias Workbench.Widgets.Pane

  defmodule ExampleSite do
    @behaviour Switchyard.Contracts.SiteProvider

    @impl true
    def site_definition do
      SiteDescriptor.new!(%{
        id: "example",
        title: "Example",
        provider: __MODULE__,
        kind: :remote
      })
    end

    @impl true
    def apps do
      [
        AppDescriptor.new!(%{
          id: "example.workspace",
          site_id: "example",
          title: "Workspace",
          provider: __MODULE__,
          resource_kinds: [:workspace],
          route_kind: :workspace,
          tui_component: Switchyard.TUICLITest.ExampleComponent
        })
      ]
    end

    @impl true
    def actions, do: []

    @impl true
    def resources(_snapshot), do: []

    @impl true
    def detail(_resource, _snapshot), do: raise("not used")
  end

  defmodule ExampleComponent do
    @behaviour Workbench.Component

    @impl true
    def init(_props, _ctx) do
      command =
        Workbench.Cmd.async(
          fn -> :opened end,
          fn :opened -> {:mounted_ready, true} end
        )

      {:ok, %{opened?: true}, [command]}
    end

    @impl true
    def update(_msg, _state, _props, _ctx), do: :unhandled

    @impl true
    def render(_state, _props, _ctx),
      do: Pane.new(id: :workspace, title: "Workspace", lines: ["ready"])
  end

  test "parse_run_opts resolves debug logging and ignores unrelated args" do
    opts = CLI.parse_run_opts(["--debug", "--bogus"])

    assert Keyword.get(opts, :log_level) == "debug"
  end

  test "escript bootstrap is a no-op outside escript runtime" do
    assert :ok = EscriptBootstrap.start_tui_dependencies()
  end

  test "app init can open a custom app component directly" do
    assert {:ok, %Workbench.Runtime.State{} = state, commands: commands} =
             App.init(
               site_modules: [ExampleSite],
               open_app: "example.workspace"
             )

    root_state = state.root_state

    assert root_state.shell.route == :app
    assert root_state.shell.selected_site_id == "example"
    assert root_state.shell.selected_app_id == "example.workspace"
    assert [%Command{kind: :async}] = commands
  end

  test "app update stops cleanly on quit messages" do
    assert {:ok, %Workbench.Runtime.State{} = state, commands: []} = App.init([])
    assert {:stop, ^state} = App.update({:info, :quit}, state)
  end
end
