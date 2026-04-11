defmodule Switchyard.TUICLITest do
  use ExUnit.Case, async: true

  alias ExRatatui.Command
  alias Switchyard.Contracts.{AppDescriptor, SiteDescriptor}
  alias Switchyard.TUI.App
  alias Switchyard.TUI.CLI
  alias Switchyard.TUI.Model
  alias Switchyard.TUI.Mount

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
          route_kind: :workspace
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

  defmodule ExampleMount do
    @behaviour Mount

    @impl true
    def id, do: "example.workspace"

    @impl true
    def init(_opts), do: %{opened?: false}

    @impl true
    def open(model, state) do
      command =
        Command.async(
          fn -> :opened end,
          fn :opened -> {:mounted_ready, true} end
        )

      {Model.set_status(model, "Opening workspace...", :info), %{state | opened?: true},
       [command]}
    end

    @impl true
    def event_to_msg(_event, _model, _state), do: :ignore

    @impl true
    def update(_msg, _model, _state), do: :unhandled

    @impl true
    def render(_model, _frame, _state), do: []
  end

  test "parse_run_opts resolves debug logging and ignores unrelated args" do
    opts = CLI.parse_run_opts(["--debug", "--bogus"])

    assert Keyword.get(opts, :log_level) == "debug"
  end

  test "app init can open an external mounted app directly" do
    assert {:ok, %Model{} = state, commands: commands} =
             App.init(
               site_modules: [ExampleSite],
               mount_modules: [ExampleMount],
               open_app: "example.workspace"
             )

    assert state.shell.route == :app
    assert state.shell.selected_site_id == "example"
    assert state.shell.selected_app_id == "example.workspace"
    assert state.mount_states["example.workspace"].opened?
    assert [%Command{kind: :async}] = Command.normalize(commands)
  end
end
