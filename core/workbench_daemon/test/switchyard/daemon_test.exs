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
end
