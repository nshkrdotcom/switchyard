defmodule Switchyard.TUITest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.OperatorTerminal
  alias Switchyard.Contracts.{AppDescriptor, Resource, ResourceDetail, SiteDescriptor}
  alias Switchyard.TUI
  alias Switchyard.TUI.App
  alias Switchyard.TUI.State

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
          id: "example.notes",
          site_id: "example",
          title: "Notes",
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
        }),
        Resource.new!(%{
          site_id: "example",
          kind: :job,
          id: "job-1",
          title: "Ignored job",
          subtitle: "queued",
          status: :queued,
          summary: "should be filtered"
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

  test "exposes the initial shell state" do
    assert %{route: :home} = TUI.initial_shell_state()
  end

  test "tracks site selection and filters resources by app kind" do
    apps = ExampleSite.apps()

    state =
      State.new(
        sites: [%{id: "local", title: "Local"}, %{id: "example", title: "Example"}],
        apps: apps,
        snapshot: %{processes: [], jobs: []},
        home_cursor: 1,
        shell: %{
          State.new().shell
          | selected_site_id: "example",
            selected_app_id: "example.notes"
        }
      )

    assert State.selected_home_site(state).id == "example"
    assert State.selected_site_app(state).id == "example.notes"
    assert [%{id: "note-1"}] = State.resources_for_selected_app(state)
  end

  test "ssh operator serving routes through execution plane operator terminal" do
    terminal_id = "switchyard-ssh-#{System.unique_integer([:positive])}"

    snapshot = %{
      processes: [],
      jobs: [],
      operator_terminals: [],
      runs: [],
      boundary_sessions: [],
      attach_grants: []
    }

    parent = self()

    on_exit(fn ->
      assert OperatorTerminal.stop(terminal_id) in [:ok, {:error, :not_found}]
      :ok
    end)

    daemon_starter = fn port, daemon_opts ->
      send(parent, {:ssh_daemon_started, port, daemon_opts})
      {:ok, {:fake_daemon, port}}
    end

    daemon_stopper = fn ref ->
      send(parent, {:ssh_daemon_stopped, ref})
      :ok
    end

    task =
      Task.async(fn ->
        TUI.run(
          request_handler: fn :local_snapshot, _opts -> snapshot end,
          snapshot: snapshot,
          site_modules: [ExampleSite],
          transport: :ssh,
          surface_ref: terminal_id,
          port: 4022,
          daemon_starter: daemon_starter,
          daemon_stopper: daemon_stopper,
          auth_methods: ~c"password",
          user_passwords: [{~c"demo", ~c"demo"}]
        )
      end)

    assert_receive {:ssh_daemon_started, 4022, daemon_opts}
    assert daemon_opts[:auth_methods] == ~c"password"

    assert %OperatorTerminal.Info{} = info = wait_for_operator_terminal(terminal_id)
    assert info.mod == App
    assert info.surface_kind == :ssh_terminal
    assert info.adapter_metadata[:port] == 4022
    assert info.transport_options[:port] == 4022
    assert info.transport_options[:auth_methods] == ~c"password"

    assert :ok = OperatorTerminal.stop(terminal_id)
    assert_receive {:ssh_daemon_stopped, {:fake_daemon, 4022}}
    assert :ok = Task.await(task, 5_000)
  end

  defp wait_for_operator_terminal(terminal_id) do
    Enum.reduce_while(1..50, nil, fn _attempt, _acc ->
      case OperatorTerminal.info(terminal_id) do
        %OperatorTerminal.Info{} = info ->
          {:halt, info}

        nil ->
          Process.sleep(20)
          {:cont, nil}
      end
    end)
  end
end
