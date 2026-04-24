defmodule Switchyard.TUIBootstrapTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.OperatorTerminal
  alias Switchyard.Contracts.{AppDescriptor, Resource, ResourceDetail, SiteDescriptor}
  alias Switchyard.TUI

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

  test "starts operator-terminal runtime when invoked outside a started app tree" do
    terminal_id = "switchyard-ssh-bootstrap-#{System.unique_integer([:positive])}"

    snapshot = %{
      processes: [],
      jobs: [],
      operator_terminals: [],
      runs: [],
      boundary_sessions: [],
      attach_grants: []
    }

    assert :ok = stop_application(:execution_plane_operator_terminal)
    assert Process.whereis(ExecutionPlane.OperatorTerminal.Supervisor) == nil

    parent = self()

    on_exit(fn ->
      assert OperatorTerminal.stop(terminal_id) in [:ok, {:error, :not_found}]

      assert {:ok, _started_apps} =
               Application.ensure_all_started(:execution_plane_operator_terminal)

      :ok
    end)

    daemon_starter = fn port, daemon_opts ->
      send(parent, {:bootstrap_ssh_daemon_started, port, daemon_opts})
      {:ok, {:bootstrap_fake_daemon, port}}
    end

    daemon_stopper = fn ref ->
      send(parent, {:bootstrap_ssh_daemon_stopped, ref})
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
          port: 4122,
          daemon_starter: daemon_starter,
          daemon_stopper: daemon_stopper,
          auth_methods: ~c"password",
          user_passwords: [{~c"demo", ~c"demo"}]
        )
      end)

    assert_receive {:bootstrap_ssh_daemon_started, 4122, daemon_opts}, 2_000
    assert daemon_opts[:auth_methods] == ~c"password"

    assert %{surface_kind: :ssh_terminal} = info = OperatorTerminal.info(terminal_id)
    assert info.surface_kind == :ssh_terminal
    assert info.adapter_metadata[:port] == 4122
    assert Process.whereis(ExecutionPlane.OperatorTerminal.Supervisor)
    assert :ok = OperatorTerminal.stop(terminal_id)
    assert_receive {:bootstrap_ssh_daemon_stopped, {:bootstrap_fake_daemon, 4122}}, 2_000
    assert :ok = Task.await(task, 5_000)
  end

  defp stop_application(app) do
    case Application.stop(app) do
      :ok -> :ok
      {:error, {:not_started, ^app}} -> :ok
    end
  end
end
