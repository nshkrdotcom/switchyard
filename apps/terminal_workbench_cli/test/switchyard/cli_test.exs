defmodule Switchyard.CLITest do
  use ExUnit.Case, async: false

  alias Switchyard.CLI
  alias Switchyard.Daemon
  alias Switchyard.Site.{ExecutionPlane, Jido}

  setup do
    {:ok, daemon} =
      start_supervised({Daemon, site_modules: [ExecutionPlane, Jido], name: nil})

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
    assert Enum.any?(sites, &(&1.id == "execution_plane"))
    assert Enum.any?(sites, &(&1.id == "jido"))
  end

  test "lists apps for a site", %{daemon: daemon} do
    assert {:ok, apps} = CLI.run(["apps", "execution_plane"], daemon: daemon)
    assert Enum.any?(apps, &(&1.id == "execution_plane.processes"))
  end

  test "returns the workspace snapshot", %{daemon: daemon} do
    assert {:ok, snapshot} = CLI.run(["snapshot"], daemon: daemon)

    assert snapshot == %{
             attach_grants: [],
             boundary_sessions: [],
             jobs: [],
             operator_terminals: [],
             processes: [],
             runs: []
           }
  end

  test "parses explicit process start flags into a structured execution spec" do
    assert {:ok, spec} =
             CLI.parse_process_start_spec([
               "--label",
               "Echo",
               "--command",
               "printf 'hello\\n'",
               "--cwd",
               "/tmp",
               "--surface-kind",
               "ssh_exec",
               "--ssh-host",
               "demo.internal",
               "--ssh-port",
               "2222",
               "--ssh-user",
               "deploy",
               "--sandbox",
               "read_only",
               "--sandbox-prefix=sh",
               "--sandbox-prefix=-lc",
               "--sandbox-prefix=exec \"$@\"",
               "--sandbox-prefix=sandbox",
               "--env=FOO=bar",
               "--arg=--version"
             ])

    assert (spec["label"] || spec[:label]) == "Echo"
    assert spec[:cwd] == "/tmp"
    assert spec[:sandbox] == "read_only"
    assert spec[:env] == %{"FOO" => "bar"}
    assert spec[:args] == ["--version"]
    assert spec[:execution_surface][:surface_kind] == "ssh_exec"
    assert spec[:execution_surface][:transport_options][:host] == "demo.internal"
    assert spec[:execution_surface][:transport_options][:port] == 2222
    assert spec[:execution_surface][:transport_options][:user] == "deploy"
  end

  test "parses process start specs from json" do
    assert {:ok,
            %{"command" => "hostname", "execution_surface" => %{"surface_kind" => "ssh_exec"}}} =
             CLI.parse_process_start_spec([
               "--spec-json",
               ~s({"command":"hostname","execution_surface":{"surface_kind":"ssh_exec"}})
             ])
  end

  test "starts a process through the daemon request seam", %{daemon: daemon} do
    assert {:ok, result} =
             CLI.run(
               ["process", "start", "--id", "echo", "--command", "printf 'hello\\n'"],
               daemon: daemon
             )

    assert result.status == :accepted

    Process.sleep(150)
    assert {:ok, snapshot} = CLI.run(["snapshot"], daemon: daemon)
    assert Enum.any?(snapshot.processes, &(&1.id == "echo"))
  end

  test "rejects unknown commands", %{daemon: daemon} do
    assert {:error, _message} = CLI.run(["bogus"], daemon: daemon)
  end
end
