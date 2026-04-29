defmodule Switchyard.DaemonTest do
  use ExUnit.Case, async: false

  alias Switchyard.Contracts.{Action, ActionResult, AppDescriptor, SiteDescriptor}
  alias Switchyard.Daemon
  alias Switchyard.Store.Local

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
          provider: __MODULE__,
          input_schema: %{
            "type" => "object",
            "required" => ["command"],
            "properties" => %{"command" => %{"type" => "string"}}
          }
        }),
        Action.new!(%{
          id: "local.process.stop",
          title: "Stop process",
          scope: {:resource, :process},
          provider: __MODULE__,
          confirmation: :if_destructive
        }),
        Action.new!(%{
          id: "local.process.force_stop",
          title: "Force stop process",
          scope: {:resource, :process},
          provider: __MODULE__,
          confirmation: :if_destructive
        }),
        Action.new!(%{
          id: "local.process.signal",
          title: "Signal process",
          scope: {:resource, :process},
          provider: __MODULE__
        }),
        Action.new!(%{
          id: "local.process.restart",
          title: "Restart process",
          scope: {:resource, :process},
          provider: __MODULE__,
          confirmation: :if_destructive
        }),
        Action.new!(%{
          id: "local.status.refresh",
          title: "Refresh status",
          scope: {:site, "local"},
          provider: __MODULE__
        })
      ]
    end

    def execute_action("local.status.refresh", input, context) do
      {:ok,
       ActionResult.new!(%{
         status: :succeeded,
         message: "status refreshed",
         output: %{input: input, site_id: context.site_id}
       })}
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

  test "lists actions through daemon request envelope", %{daemon: daemon} do
    assert [
             %Action{id: "local.process.start"},
             %Action{id: "local.process.stop"},
             %Action{id: "local.process.force_stop"},
             %Action{id: "local.process.signal"},
             %Action{id: "local.process.restart"},
             %Action{id: "local.status.refresh"}
           ] = request(daemon, %{kind: :actions})
  end

  test "lists actions for one site through daemon request envelope", %{daemon: daemon} do
    assert [
             %Action{id: "local.process.start"},
             %Action{id: "local.process.stop"},
             %Action{id: "local.process.force_stop"},
             %Action{id: "local.process.signal"},
             %Action{id: "local.process.restart"},
             %Action{id: "local.status.refresh"}
           ] = request(daemon, %{kind: :actions, site_id: "local"})
  end

  test "lists resource-scoped actions through daemon request envelope", %{daemon: daemon} do
    assert [
             %Action{id: "local.process.stop"},
             %Action{id: "local.process.force_stop"},
             %Action{id: "local.process.signal"},
             %Action{id: "local.process.restart"}
           ] =
             request(daemon, %{
               kind: :actions,
               resource: %{site_id: "local", kind: :process, id: "echo"}
             })
  end

  test "rejects unknown actions", %{daemon: daemon} do
    assert {:error,
            %{
              reason: :unknown_action,
              action_id: "missing.action",
              message: "unknown action"
            }} =
             request(daemon, %{
               kind: :execute_action,
               action_id: "missing.action",
               input: %{}
             })
  end

  test "rejects action scope mismatches", %{daemon: daemon} do
    assert {:error,
            %{
              reason: :scope_mismatch,
              action_id: "local.process.stop"
            }} =
             request(daemon, %{
               kind: :execute_action,
               action_id: "local.process.stop",
               site_id: "local",
               input: %{}
             })
  end

  test "validates required action input", %{daemon: daemon} do
    assert {:error,
            %{
              reason: :invalid_input,
              action_id: "local.process.start",
              missing: ["command"]
            }} =
             request(daemon, %{
               kind: :execute_action,
               action_id: "local.process.start",
               site_id: "local",
               input: %{"id" => "missing-command"}
             })
  end

  test "enforces destructive confirmation", %{daemon: daemon} do
    assert {:ok, %ActionResult{status: :accepted}} =
             request(daemon, %{
               kind: :execute_action,
               action_id: "local.process.start",
               site_id: "local",
               input: %{id: "long", label: "Long", command: "sleep 5"}
             })

    assert {:error,
            %{
              reason: :confirmation_required,
              action_id: "local.process.stop",
              retryable?: true
            }} =
             request(daemon, %{
               kind: :execute_action,
               action_id: "local.process.stop",
               resource: %{site_id: "local", kind: :process, id: "long"},
               input: %{}
             })

    assert {:ok, %ActionResult{status: :accepted, message: "process stopped"}} =
             request(daemon, %{
               kind: :execute_action,
               action_id: "local.process.stop",
               resource: %{site_id: "local", kind: :process, id: "long"},
               input: %{},
               confirmed?: true
             })
  end

  test "returns action result shape for site-level provider dispatch", %{daemon: daemon} do
    assert {:ok,
            %ActionResult{
              status: :succeeded,
              message: "status refreshed",
              output: %{input: %{"force" => true}, site_id: "local"}
            }} =
             request(daemon, %{
               kind: :execute_action,
               action_id: "local.status.refresh",
               site_id: "local",
               input: %{"force" => true}
             })
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
    assert Enum.any?(snapshot.streams, &(&1.id == "logs/echo"))
    assert Enum.any?(logs, &(&1.message == "hello"))
    assert File.exists?(Path.join([store_root, "daemon", "local_snapshot.json"]))
  end

  test "uses typed lifecycle states and creates job and stream metadata", %{daemon: daemon} do
    assert {:ok, %ActionResult{status: :accepted, job_id: "job-lifecycle"}} =
             Daemon.start_process(daemon, %{
               id: "lifecycle",
               label: "Lifecycle",
               command: "sleep 5"
             })

    snapshot = Daemon.snapshot(daemon)
    process = Enum.find(snapshot.processes, &(&1.id == "lifecycle"))

    assert process.status == :running
    assert process.status_reason == :runtime_started
    assert is_struct(process.started_at, DateTime)
    assert is_struct(process.last_seen_at, DateTime)
    assert process.exit_status == nil
    assert process.job_ids == ["job-lifecycle"]
    assert process.stream_ids == ["logs/lifecycle", "jobs/job-lifecycle"]
    assert process.env_summary == %{keys: [], count: 0, clear_env?: false}
    assert Enum.any?(snapshot.jobs, &(&1.id == "job-lifecycle" and &1.status == :running))
    assert Enum.any?(snapshot.streams, &(&1.id == "logs/lifecycle"))
    assert Enum.any?(snapshot.streams, &(&1.id == "jobs/job-lifecycle"))

    assert {:ok, %ActionResult{status: :accepted}} = Daemon.stop_process(daemon, "lifecycle")
  end

  test "lists streams and filters streams by resource", %{daemon: daemon} do
    assert {:ok, %ActionResult{status: :accepted}} =
             Daemon.start_process(daemon, %{id: "streamed", command: "sleep 5"})

    assert streams = request(daemon, %{kind: :streams})
    assert Enum.any?(streams, &(&1.id == "logs/streamed" and &1.kind == :process_combined))
    assert Enum.any?(streams, &(&1.id == "jobs/job-streamed" and &1.kind == :job_events))

    assert [%{id: "logs/streamed"}] =
             request(daemon, %{
               kind: :streams,
               resource: %{site_id: "execution_plane", kind: :process, id: "streamed"}
             })

    assert {:ok, %ActionResult{status: :accepted}} = Daemon.stop_process(daemon, "streamed")
  end

  test "tails and filters sequenced log events with stream metadata", %{daemon: daemon} do
    assert {:ok, %ActionResult{status: :accepted}} =
             Daemon.start_process(daemon, %{id: "loggy", command: "sleep 5"})

    send(daemon, {:process_output, "loggy", "one", %{fd: :stdout}})
    send(daemon, {:process_output, "loggy", "two", %{fd: :stderr}})
    send(daemon, {:process_output, "loggy", "three", %{fd: :stdout}})

    Process.sleep(50)

    assert [one, two, three] = request(daemon, %{kind: :logs, stream_id: "logs/loggy"})
    assert Enum.map([one, two, three], & &1.fields[:seq]) == [1, 2, 3]
    assert one.fields[:fd] == :stdout
    assert one.fields[:process_id] == "loggy"
    assert two.fields[:fd] == :stderr

    assert ["two", "three"] =
             daemon
             |> request(%{kind: :logs, stream_id: "logs/loggy", tail: 2})
             |> Enum.map(& &1.message)

    assert ["three"] =
             daemon
             |> request(%{kind: :logs, stream_id: "logs/loggy", after_seq: 2})
             |> Enum.map(& &1.message)

    assert ["one", "two", "three"] =
             daemon
             |> request(%{
               kind: :logs,
               stream_id: "logs/loggy",
               level: :info,
               source_kind: :process,
               process_id: "loggy"
             })
             |> Enum.map(& &1.message)

    assert [] =
             request(daemon, %{
               kind: :logs,
               stream_id: "logs/loggy",
               source_kind: :process,
               process_id: "other"
             })

    assert [] = request(daemon, %{kind: :logs, stream_id: "logs/loggy", level: :error})
    assert {:ok, %ActionResult{status: :accepted}} = Daemon.stop_process(daemon, "loggy")
  end

  test "emits job event streams", %{daemon: daemon} do
    assert {:ok, %ActionResult{status: :accepted}} =
             Daemon.start_process(daemon, %{id: "job-events", command: "sleep 5"})

    assert [event] = request(daemon, %{kind: :logs, stream_id: "jobs/job-job-events"})
    assert event.source_kind == :job
    assert event.fields[:job_id] == "job-job-events"
    assert event.fields[:event_kind] == :running

    assert [^event] =
             request(daemon, %{
               kind: :logs,
               stream_id: "jobs/job-job-events",
               job_id: "job-job-events"
             })

    assert [] =
             request(daemon, %{
               kind: :logs,
               stream_id: "jobs/job-job-events",
               job_id: "other"
             })

    assert {:ok, %ActionResult{status: :accepted}} = Daemon.stop_process(daemon, "job-events")
  end

  test "redacts env values before persistence", %{daemon: daemon, store_root: store_root} do
    assert {:ok, %ActionResult{status: :accepted}} =
             Daemon.start_process(daemon, %{
               id: "redacted",
               command: "sleep 5",
               env: %{"SECRET_TOKEN" => "supersecret", "VISIBLE_KEY" => "public"}
             })

    persisted = File.read!(Path.join([store_root, "daemon", "local_snapshot.json"]))

    assert persisted =~ "SECRET_TOKEN"
    refute persisted =~ "supersecret"
    refute persisted =~ "public"

    assert {:ok, %ActionResult{status: :accepted}} = Daemon.stop_process(daemon, "redacted")
  end

  test "boots without a store in memory-only recovery mode" do
    {:ok, daemon} = start_supervised({Daemon, site_modules: [FakeLocalSite], name: nil})

    assert %{recovery_status: %{status: :ok, mode: :memory_only}} = Daemon.snapshot(daemon)
  end

  test "boots from a persisted snapshot and marks running processes lost" do
    root = store_root("daemon-recovery-running")
    on_exit(fn -> File.rm_rf(root) end)

    :ok = write_recovery_snapshot(root, [persisted_process("lost-running", "running")])

    {:ok, daemon} =
      start_supervised({Daemon, site_modules: [FakeLocalSite], store_root: root, name: nil})

    snapshot = Daemon.snapshot(daemon)
    process = Enum.find(snapshot.processes, &(&1.id == "lost-running"))

    assert process.status == :lost
    assert process.status_reason == :daemon_restarted_without_reconnect
    assert process.pid == nil
    assert snapshot.recovery_status.status == :degraded
    assert "lost-running" in snapshot.recovery_status.lost_processes
  end

  test "keeps terminal processes terminal during recovery" do
    root = store_root("daemon-recovery-terminal")
    on_exit(fn -> File.rm_rf(root) end)

    :ok = write_recovery_snapshot(root, [persisted_process("stopped-process", "stopped")])

    {:ok, daemon} =
      start_supervised({Daemon, site_modules: [FakeLocalSite], store_root: root, name: nil})

    snapshot = Daemon.snapshot(daemon)
    process = Enum.find(snapshot.processes, &(&1.id == "stopped-process"))

    assert process.status == :stopped
    assert process.status_reason == :operator_requested
    assert snapshot.recovery_status.status == :ok
  end

  test "replays process journal events after the current snapshot" do
    root = store_root("daemon-recovery-journal")
    on_exit(fn -> File.rm_rf(root) end)

    :ok = write_recovery_snapshot(root, [])

    :ok =
      Local.append_journal(root, "daemon", "journal-current", %{
        "schema_version" => 1,
        "seq" => 1,
        "kind" => "process_started",
        "payload" => %{"process" => persisted_process("journaled-running", "running")}
      })

    {:ok, daemon} =
      start_supervised({Daemon, site_modules: [FakeLocalSite], store_root: root, name: nil})

    snapshot = Daemon.snapshot(daemon)
    assert Enum.any?(snapshot.processes, &(&1.id == "journaled-running" and &1.status == :lost))
  end

  test "fails boot with an explicit malformed persisted snapshot error" do
    previous_trap_exit = Process.flag(:trap_exit, true)
    on_exit(fn -> Process.flag(:trap_exit, previous_trap_exit) end)

    root = store_root("daemon-recovery-malformed")
    on_exit(fn -> File.rm_rf(root) end)

    :ok =
      Local.put_manifest(root, "daemon", %{
        "schema_version" => 1,
        "current_snapshot" => "current",
        "current_journal" => "journal-current"
      })

    snapshot_path = Path.join([root, "daemon", "snapshots", "current.json"])
    File.mkdir_p!(Path.dirname(snapshot_path))
    File.write!(snapshot_path, "{bad-json")

    assert {:error, {:recovery_failed, {:malformed_snapshot, _reason}}} =
             Daemon.start_link(site_modules: [FakeLocalSite], store_root: root, name: nil)
  end

  test "records successful and failed process exits", %{daemon: daemon} do
    assert {:ok, %ActionResult{status: :accepted}} =
             Daemon.start_process(daemon, %{id: "success", command: "exit 0"})

    assert {:ok, %ActionResult{status: :accepted}} =
             Daemon.start_process(daemon, %{id: "failure", command: "exit 3"})

    Process.sleep(200)

    snapshot = Daemon.snapshot(daemon)
    success = Enum.find(snapshot.processes, &(&1.id == "success"))
    failure = Enum.find(snapshot.processes, &(&1.id == "failure"))

    assert success.status == :succeeded
    assert success.status_reason == :exit_zero
    assert success.exit_status == 0
    assert is_struct(success.stopped_at, DateTime)

    assert failure.status == :failed
    assert failure.status_reason == :exit_nonzero
    assert failure.exit_status == 3
    assert is_struct(failure.stopped_at, DateTime)
  end

  test "records graceful stop transition", %{daemon: daemon} do
    assert {:ok, %ActionResult{status: :accepted}} =
             Daemon.start_process(daemon, %{id: "stop-me", command: "sleep 5"})

    assert {:ok, %ActionResult{status: :accepted, job_id: "job-stop-stop-me"}} =
             Daemon.stop_process(daemon, "stop-me")

    snapshot = Daemon.snapshot(daemon)
    process = Enum.find(snapshot.processes, &(&1.id == "stop-me"))

    assert process.status == :stopped
    assert process.status_reason == :operator_requested
    assert process.exit_status == nil
    assert is_struct(process.stopped_at, DateTime)
    assert "job-stop-stop-me" in process.job_ids
    assert Enum.any?(snapshot.jobs, &(&1.id == "job-stop-stop-me" and &1.status == :succeeded))
  end

  test "rejects unsupported force stop and signal actions", %{daemon: daemon} do
    assert {:ok, %ActionResult{status: :accepted}} =
             Daemon.start_process(daemon, %{id: "unsupported", command: "sleep 5"})

    resource = %{site_id: "local", kind: :process, id: "unsupported"}

    assert {:error, %{reason: :unsupported_capability, action_id: "local.process.force_stop"}} =
             request(daemon, %{
               kind: :execute_action,
               action_id: "local.process.force_stop",
               resource: resource,
               confirmed?: true
             })

    assert {:error, %{reason: :unsupported_capability, action_id: "local.process.signal"}} =
             request(daemon, %{
               kind: :execute_action,
               action_id: "local.process.signal",
               resource: resource,
               input: %{"signal" => "TERM"}
             })

    assert {:ok, %ActionResult{status: :accepted}} = Daemon.stop_process(daemon, "unsupported")
  end

  test "rejects restart when safe restart spec is not persisted", %{daemon: daemon} do
    assert {:ok, %ActionResult{status: :accepted}} =
             Daemon.start_process(daemon, %{id: "restart-me", command: "sleep 5"})

    assert {:error,
            %{
              reason: :restart_requires_explicit_spec,
              action_id: "local.process.restart"
            }} =
             request(daemon, %{
               kind: :execute_action,
               action_id: "local.process.restart",
               resource: %{site_id: "local", kind: :process, id: "restart-me"},
               confirmed?: true
             })

    assert {:ok, %ActionResult{status: :accepted}} = Daemon.stop_process(daemon, "restart-me")
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
    assert process.sandbox["enforced"] == true
    assert process.sandbox["enforcement_surface"] == "command_prefix"
    assert process.sandbox["policy"]["has_command_prefix"] == true
    assert "command_prefix" in process.sandbox["policy"]["keys"]
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

  defp request(daemon, payload), do: GenServer.call(daemon, {:switchyard_request, payload})

  defp store_root(label) do
    Path.join(System.tmp_dir!(), "#{label}-#{System.unique_integer([:positive])}")
  end

  defp write_recovery_snapshot(root, processes) do
    with :ok <-
           Local.put_manifest(root, "daemon", %{
             "schema_version" => 1,
             "daemon_instance_id" => "test-daemon",
             "current_snapshot" => "current",
             "current_journal" => "journal-current"
           }) do
      Local.put_versioned_snapshot(root, "daemon", "current", %{
        "schema_version" => 1,
        "written_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "daemon_instance_id" => "test-daemon",
        "processes" => processes,
        "jobs" => [],
        "streams" => [],
        "operator_terminals" => [],
        "runs" => [],
        "boundary_sessions" => [],
        "attach_grants" => [],
        "recovery_status" => %{"status" => "ok", "warnings" => []}
      })
    end
  end

  defp persisted_process(process_id, status) do
    %{
      "id" => process_id,
      "label" => process_id,
      "status" => status,
      "status_reason" => status_reason(status),
      "exit_status" => nil,
      "started_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "stopped_at" => nil,
      "last_seen_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "command" => "sleep 5",
      "command_preview" => "sleep 5",
      "args" => [],
      "shell?" => true,
      "cwd" => nil,
      "env_summary" => %{"keys" => [], "count" => 0, "clear_env?" => false},
      "execution_surface" => %{"surface_kind" => "local_subprocess"},
      "sandbox" => %{"mode" => "inherit"},
      "job_ids" => ["job-#{process_id}"],
      "stream_ids" => ["logs/#{process_id}", "jobs/job-#{process_id}"]
    }
  end

  defp status_reason("stopped"), do: "operator_requested"
  defp status_reason(_status), do: "runtime_started"
end
