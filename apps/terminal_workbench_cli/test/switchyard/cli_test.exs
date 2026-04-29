defmodule Switchyard.CLITest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

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

  test "lists actions", %{daemon: daemon} do
    assert {:ok, actions} = CLI.run(["actions"], daemon: daemon)
    assert Enum.any?(actions, &(&1.id == "execution_plane.process.start"))
    assert Enum.any?(actions, &(&1.id == "jido.review.refresh"))
  end

  test "main encodes action tuple scopes as stable JSON", %{daemon: daemon} do
    previous_runtime = Application.get_env(:switchyard_cli, :runtime)
    Application.put_env(:switchyard_cli, :runtime, daemon: daemon)

    on_exit(fn ->
      if is_nil(previous_runtime) do
        Application.delete_env(:switchyard_cli, :runtime)
      else
        Application.put_env(:switchyard_cli, :runtime, previous_runtime)
      end
    end)

    output = capture_io(fn -> CLI.main(["actions", "--site", "execution_plane"]) end)
    decoded = Jason.decode!(output)

    assert Enum.any?(decoded, fn action ->
             action["id"] == "execution_plane.process.start" and
               action["scope"] == ["site", "execution_plane"]
           end)
  end

  test "lists actions for one site with explicit option syntax", %{daemon: daemon} do
    assert {:ok, actions} = CLI.run(["actions", "--site", "execution_plane"], daemon: daemon)

    assert Enum.any?(actions, &(&1.id == "execution_plane.process.start"))
    refute Enum.any?(actions, &(&1.id == "jido.review.refresh"))
  end

  test "runs site actions through the generic action command", %{daemon: daemon} do
    assert {:ok, result} =
             CLI.run(
               [
                 "action",
                 "run",
                 "jido.review.refresh",
                 "--site",
                 "jido",
                 "--input-json",
                 ~s({"force":true})
               ],
               daemon: daemon
             )

    assert result.status == :succeeded
    assert result.output == %{input: %{"force" => true}}
  end

  test "returns the workspace snapshot", %{daemon: daemon} do
    assert {:ok, snapshot} = CLI.run(["snapshot"], daemon: daemon)

    assert snapshot == %{
             attach_grants: [],
             boundary_sessions: [],
             jobs: [],
             operator_terminals: [],
             processes: [],
             recovery_status: %{mode: :memory_only, status: :ok, warnings: []},
             runs: [],
             streams: []
           }
  end

  test "reports daemon recovery status", %{daemon: daemon} do
    assert {:ok, %{status: :ok, mode: :memory_only, warnings: []}} =
             CLI.run(["recovery"], daemon: daemon)
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

  test "lists, inspects, and stops processes through daemon actions", %{daemon: daemon} do
    assert {:ok, _result} =
             CLI.run(
               ["process", "start", "--id", "cli-long", "--command", "sleep 5"],
               daemon: daemon
             )

    assert {:ok, processes} = CLI.run(["process", "list"], daemon: daemon)
    assert Enum.any?(processes, &(&1.id == "cli-long"))

    assert {:ok, process} = CLI.run(["process", "inspect", "cli-long"], daemon: daemon)
    assert process.status == :running
    assert process.stream_ids == ["logs/cli-long", "jobs/job-cli-long"]

    assert {:error, confirm_message} = CLI.run(["process", "stop", "cli-long"], daemon: daemon)
    assert confirm_message =~ "--confirm"

    assert {:ok, stop_result} =
             CLI.run(["process", "stop", "cli-long", "--confirm"], daemon: daemon)

    assert stop_result.status == :accepted
    assert stop_result.job_id == "job-stop-cli-long"
  end

  test "runs destructive resource actions through the generic action command", %{daemon: daemon} do
    assert {:ok, _result} =
             CLI.run(
               ["process", "start", "--id", "generic-stop", "--command", "sleep 5"],
               daemon: daemon
             )

    assert {:error, confirm_message} =
             CLI.run(
               [
                 "action",
                 "run",
                 "execution_plane.process.stop",
                 "--resource",
                 "process:generic-stop"
               ],
               daemon: daemon
             )

    assert confirm_message =~ "confirmation_required"

    assert {:ok, result} =
             CLI.run(
               [
                 "action",
                 "run",
                 "execution_plane.process.stop",
                 "--resource",
                 "process:generic-stop",
                 "--confirm"
               ],
               daemon: daemon
             )

    assert result.status == :accepted
    assert result.job_id == "job-stop-generic-stop"
  end

  test "lists streams and tails logs", %{daemon: daemon} do
    assert {:ok, _result} =
             CLI.run(
               ["process", "start", "--id", "cli-logs", "--command", "sleep 5"],
               daemon: daemon
             )

    send(daemon, {:process_output, "cli-logs", "first", %{fd: :stdout}})
    send(daemon, {:process_output, "cli-logs", "second", %{fd: :stderr}})
    Process.sleep(50)

    assert {:ok, streams} = CLI.run(["streams"], daemon: daemon)
    assert Enum.any?(streams, &(&1.id == "logs/cli-logs"))

    assert {:ok, [event]} = CLI.run(["logs", "logs/cli-logs", "--tail", "1"], daemon: daemon)
    assert event.message == "second"
    assert event.fields[:fd] == :stderr

    assert {:ok, [event]} =
             CLI.run(
               ["process", "logs", "cli-logs", "--after-seq", "1", "--process-id", "cli-logs"],
               daemon: daemon
             )

    assert event.message == "second"

    assert {:ok, []} =
             CLI.run(["logs", "logs/cli-logs", "--process-id", "other"], daemon: daemon)

    assert {:ok, _stop_result} =
             CLI.run(["process", "stop", "cli-logs", "--confirm"], daemon: daemon)
  end

  test "reports unsupported restart and signal process actions", %{daemon: daemon} do
    assert {:ok, _result} =
             CLI.run(
               ["process", "start", "--id", "cli-unsupported", "--command", "sleep 5"],
               daemon: daemon
             )

    assert {:error, restart_message} =
             CLI.run(["process", "restart", "cli-unsupported", "--confirm"], daemon: daemon)

    assert restart_message =~ "restart_requires_explicit_spec"

    assert {:error, signal_message} =
             CLI.run(["process", "signal", "cli-unsupported", "TERM"], daemon: daemon)

    assert signal_message =~ "unsupported_capability"

    assert {:ok, _stop_result} =
             CLI.run(["process", "stop", "cli-unsupported", "--confirm"], daemon: daemon)
  end

  test "rejects unknown commands", %{daemon: daemon} do
    assert {:error, _message} = CLI.run(["bogus"], daemon: daemon)
  end
end
