defmodule Switchyard.CLITest do
  use ExUnit.Case, async: false

  alias Switchyard.CLI
  alias Switchyard.Daemon
  alias Switchyard.Site.Local

  setup do
    {:ok, daemon} =
      start_supervised({Daemon, site_modules: [Local], name: nil})

    %{daemon: daemon}
  end

  test "ensure_runtime_started boots an in-process daemon when missing" do
    daemon_name = :"switchyard-cli-daemon-#{System.unique_integer([:positive])}"
    refute Process.whereis(daemon_name)

    assert :ok = CLI.ensure_runtime_started(daemon: daemon_name)
    assert is_pid(Process.whereis(daemon_name))
    assert :ok = CLI.ensure_runtime_started(daemon: daemon_name)
  end

  test "lists sites", %{daemon: daemon} do
    assert {:ok, sites} = CLI.run(["sites"], daemon: daemon)
    assert Enum.any?(sites, &(&1.id == "local"))
  end

  test "lists apps for a site", %{daemon: daemon} do
    assert {:ok, apps} = CLI.run(["apps", "local"], daemon: daemon)
    assert Enum.any?(apps, &(&1.id == "local.processes"))
  end

  test "returns the local snapshot", %{daemon: daemon} do
    assert {:ok, snapshot} = CLI.run(["local", "snapshot"], daemon: daemon)
    assert snapshot == %{jobs: [], processes: []}
  end

  test "rejects unknown commands", %{daemon: daemon} do
    assert {:error, _message} = CLI.run(["bogus"], daemon: daemon)
  end
end
