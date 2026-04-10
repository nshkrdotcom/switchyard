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
end
