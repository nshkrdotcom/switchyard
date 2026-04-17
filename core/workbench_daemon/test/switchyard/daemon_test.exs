defmodule Switchyard.DaemonTest do
  use ExUnit.Case, async: false

  alias Switchyard.Contracts.{Action, AppDescriptor, SiteDescriptor}
  alias Switchyard.Daemon

  defmodule FakeLocalSite do
    def site_definition do
      SiteDescriptor.new!(%{id: "local", title: "Local", provider: __MODULE__})
    end

    def apps do
      [
        AppDescriptor.new!(%{
          id: "local.processes",
          site_id: "local",
          title: "Processes",
          provider: __MODULE__
        })
      ]
    end

    def actions do
      [
        Action.new!(%{
          id: "local.process.start",
          title: "Start process",
          scope: {:site, "local"},
          provider: __MODULE__
        })
      ]
    end
  end

  setup do
    store_root =
      Path.join(System.tmp_dir!(), "switchyard-daemon-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(store_root) end)

    {:ok, daemon} =
      start_supervised({Daemon, site_modules: [FakeLocalSite], store_root: store_root, name: nil})

    %{daemon: daemon, store_root: store_root}
  end

  test "lists configured sites and apps", %{daemon: daemon} do
    assert [%SiteDescriptor{id: "local"}] = Daemon.list_sites(daemon)
    assert [%AppDescriptor{id: "local.processes"}] = Daemon.list_apps(daemon, "local")
  end

  test "starts a managed process and captures logs", %{daemon: daemon, store_root: store_root} do
    assert {:ok, _result} =
             Daemon.start_process(daemon, %{
               id: "echo",
               label: "Echo",
               command: "printf 'hello\\n'"
             })

    Process.sleep(150)

    snapshot = Daemon.snapshot(daemon)
    logs = Daemon.logs(daemon, "logs/echo")

    assert Enum.any?(snapshot.processes, &(&1.id == "echo"))
    assert Enum.any?(snapshot.jobs, &(&1.id == "job-echo"))
    assert Enum.any?(logs, &(&1.message == "hello"))
    assert File.exists?(Path.join([store_root, "daemon", "local_snapshot.json"]))
  end

  test "preserves execution surface and sandbox metadata in snapshots", %{daemon: daemon} do
    shell = System.find_executable("sh") || "/bin/sh"

    assert {:ok, _result} =
             Daemon.start_process(daemon, %{
               id: "sandboxed",
               label: "Sandboxed Echo",
               command: "printf 'hello\\n'",
               cwd: "/tmp",
               execution_surface: %{
                 surface_kind: :local_subprocess,
                 boundary_class: :operator
               },
               sandbox: :read_only,
               sandbox_policy: %{command_prefix: [shell, "-lc", "exec \"$@\"", "sandbox"]}
             })

    Process.sleep(150)

    snapshot = Daemon.snapshot(daemon)
    process = Enum.find(snapshot.processes, &(&1.id == "sandboxed"))

    assert process.command == "printf 'hello\\n'"
    assert process.command_preview =~ "printf"
    assert process.cwd == "/tmp"
    assert process.execution_surface["surface_kind"] == "local_subprocess"
    assert process.execution_surface["boundary_class"] == "operator"
    assert process.sandbox["mode"] == "read_only"
    assert process.sandbox["policy"]["has_command_prefix"] == true
  end

  test "returns a rich error payload when process start validation fails", %{daemon: daemon} do
    assert {:error, %{reason: {:invalid_pty, "yes"}, command_preview: preview}} =
             Daemon.start_process(daemon, %{
               id: "bad",
               command: "printf 'hello\\n'",
               pty?: "yes"
             })

    assert preview =~ "invalid_pty"
  end
end
