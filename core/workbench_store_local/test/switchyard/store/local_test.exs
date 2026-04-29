defmodule Switchyard.Store.LocalTest do
  use ExUnit.Case, async: true

  alias Switchyard.Store.Local

  setup do
    root = Path.join(System.tmp_dir!(), "switchyard-store-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf(root) end)
    %{root: root}
  end

  test "persists and loads snapshots", %{root: root} do
    assert :ok =
             Local.put_snapshot(root, "sites", "local", %{
               "id" => "local",
               "title" => "Local"
             })

    assert {:ok, %{"id" => "local", "title" => "Local"}} =
             Local.get_snapshot(root, "sites", "local")
  end

  test "lists bucket keys", %{root: root} do
    :ok = Local.put_snapshot(root, "jobs", "job-2", %{"status" => "running"})
    :ok = Local.put_snapshot(root, "jobs", "job-1", %{"status" => "queued"})

    assert Local.list_keys(root, "jobs") == ["job-1", "job-2"]
  end

  test "persists and loads manifests", %{root: root} do
    manifest = %{
      "schema_version" => 1,
      "daemon_instance_id" => "daemon-test",
      "current_snapshot" => "current",
      "current_journal" => "journal-current"
    }

    assert :ok = Local.put_manifest(root, "daemon", manifest)
    assert {:ok, ^manifest} = Local.get_manifest(root, "daemon")
  end

  test "persists, loads, and migrates versioned snapshots", %{root: root} do
    snapshot = %{
      "schema_version" => 1,
      "processes" => [],
      "jobs" => [],
      "streams" => [],
      "recovery_status" => %{"status" => "ok"}
    }

    assert :ok = Local.put_versioned_snapshot(root, "daemon", "current", snapshot)
    assert {:ok, ^snapshot} = Local.get_versioned_snapshot(root, "daemon", "current")

    old_snapshot = Map.put(snapshot, "schema_version", 0)
    assert :ok = Local.put_versioned_snapshot(root, "daemon", "old", old_snapshot)
    assert {:ok, migrated} = Local.get_versioned_snapshot(root, "daemon", "old")
    assert migrated["schema_version"] == 1
    assert [%{"from" => 0, "to" => 1} | _rest] = migrated["migration_history"]
  end

  test "appends and reads journal events", %{root: root} do
    event = %{
      "schema_version" => 1,
      "seq" => 1,
      "kind" => "process_started",
      "payload" => %{"process" => %{"id" => "proc-1", "status" => "running"}}
    }

    assert :ok = Local.append_journal(root, "daemon", "journal-current", event)
    assert {:ok, [^event]} = Local.read_journal(root, "daemon", "journal-current")
  end

  test "returns an explicit malformed snapshot error", %{root: root} do
    snapshot_path = Path.join([root, "daemon", "snapshots", "current.json"])
    File.mkdir_p!(Path.dirname(snapshot_path))
    File.write!(snapshot_path, "{not-json")

    assert {:error, {:malformed_snapshot, _reason}} =
             Local.get_versioned_snapshot(root, "daemon", "current")
  end
end
