defmodule Switchyard.Examples.CurrentDaemonSmokeTest do
  use ExUnit.Case, async: false

  alias Switchyard.Contracts.{Action, AppDescriptor, SiteDescriptor}
  alias Switchyard.Daemon

  defmodule SmokeSite do
    def site_definition do
      SiteDescriptor.new!(%{id: "smoke", title: "Smoke", provider: __MODULE__})
    end

    def apps do
      [
        AppDescriptor.new!(%{
          id: "smoke.processes",
          site_id: "smoke",
          title: "Processes",
          provider: __MODULE__
        })
      ]
    end

    def actions do
      [
        Action.new!(%{
          id: "smoke.process.start",
          title: "Start process",
          scope: {:site, "smoke"},
          provider: __MODULE__,
          input_schema: %{"required" => ["command"]}
        }),
        Action.new!(%{
          id: "smoke.process.stop",
          title: "Stop process",
          scope: {:resource, :process},
          provider: __MODULE__,
          confirmation: :if_destructive
        })
      ]
    end
  end

  test "daemon starts a process, exposes snapshot state, logs output, and stops it" do
    {:ok, daemon} = start_supervised({Daemon, site_modules: [SmokeSite], name: nil})

    assert {:ok, start_result} =
             Daemon.start_process(daemon, %{
               id: "example-smoke",
               command: "printf 'example smoke\\n'"
             })

    assert start_result.status == :accepted
    Process.sleep(150)

    snapshot = Daemon.snapshot(daemon)
    assert Enum.any?(snapshot.processes, &(&1.id == "example-smoke"))
    assert Enum.any?(snapshot.jobs, &(&1.id == "job-example-smoke"))
    assert Enum.any?(snapshot.streams, &(&1.id == "logs/example-smoke"))

    assert Enum.any?(Daemon.logs(daemon, "logs/example-smoke"), &(&1.message == "example smoke"))
    assert snapshot.recovery_status.status == :ok
  end
end
