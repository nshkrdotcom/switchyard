defmodule Switchyard.TUICLITest do
  use ExUnit.Case, async: true

  alias ExRatatui.Command
  alias Switchyard.Contracts.{AppDescriptor, SiteDescriptor}
  alias Switchyard.TUI.App
  alias Switchyard.TUI.CLI
  alias Switchyard.TUI.EscriptBootstrap
  alias Workbench.Devtools.Driver
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

  test "parse_run_opts resolves real debug mode and ignores unrelated args" do
    opts = CLI.parse_run_opts(["--debug", "--debug-dir", "/tmp/switchyard-debug", "--bogus"])

    assert Keyword.get(opts, :log_level) == "debug"
    assert Keyword.get(opts, :debug) == true
    assert Keyword.get(opts, :debug_dir) == "/tmp/switchyard-debug"
  end

  test "parse_run_opts enables ssh transport defaults" do
    opts = CLI.parse_run_opts(["--ssh", "--ssh-port", "3022", "--ssh-user", "admin"])

    assert Keyword.get(opts, :transport) == :ssh
    assert Keyword.get(opts, :port) == 3022
    assert Keyword.get(opts, :auto_host_key) == true
    assert Keyword.get(opts, :auth_methods) == ~c"password"
    assert Keyword.get(opts, :user_passwords) == [{~c"admin", ~c"demo"}]
  end

  test "parse_run_opts enables distributed transport" do
    opts = CLI.parse_run_opts(["--distributed"])

    assert Keyword.get(opts, :transport) == :distributed
  end

  test "escript bootstrap is a no-op outside escript runtime" do
    assert :ok = EscriptBootstrap.start_tui_dependencies()
  end

  test "app init can open a custom app component directly" do
    assert {:ok, %Workbench.Runtime.State{} = state, runtime_opts} =
             App.init(
               site_modules: [ExampleSite],
               open_app: "example.workspace"
             )

    root_state = state.root_state

    assert root_state.shell.route == :app
    assert root_state.shell.selected_site_id == "example"
    assert root_state.shell.selected_app_id == "example.workspace"
    assert [%Command{kind: :async}] = runtime_opts[:commands]
    assert runtime_opts[:render?] == true
    assert runtime_opts[:trace?] == nil
  end

  test "app init enables real debug runtime state" do
    base_dir =
      Path.join(System.tmp_dir!(), "switchyard_tui_debug_#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(base_dir) end)

    assert {:ok, %Workbench.Runtime.State{} = state, _runtime_opts} =
             App.init(debug: true, debug_dir: base_dir)

    assert state.devtools.enabled? == true
    assert is_binary(state.devtools.artifact_dir)
    assert state.root_state.debug_overlay_visible == true
  end

  test "driver can fetch workbench debug snapshots from a running app" do
    base_dir =
      Path.join(System.tmp_dir!(), "switchyard_tui_driver_#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(base_dir) end)

    assert {:ok, pid} =
             App.start_link(
               name: nil,
               debug: true,
               debug_dir: base_dir,
               test_mode: {90, 28}
             )

    assert %{enabled?: true, latest: %{route: :home, render_tree_entries: entry_count}} =
             Driver.wait_for_debug_snapshot!(pid, "debug startup", fn snapshot ->
               Map.get(snapshot, :enabled?, false) and
                 match?(%{route: :home}, Map.get(snapshot, :latest))
             end)

    assert entry_count > 0
    GenServer.stop(pid)
  end

  test "app update stops cleanly on quit messages" do
    assert {:ok, %Workbench.Runtime.State{} = state, runtime_opts} = App.init([])
    assert runtime_opts[:commands] == []
    assert {:stop, ^state} = App.update({:info, :quit}, state)
  end
end
