defmodule WorkbenchDevtoolsTest do
  use ExUnit.Case, async: true

  alias Workbench.Devtools.{History, Inspector, Overlay, RenderStats, SessionArtifacts}

  test "builds inspectable snapshots and bounded history" do
    snapshot =
      Inspector.snapshot(
        enabled?: true,
        artifact_dir: "/tmp/example",
        commands: [%{kind: :async}],
        subscriptions: [:tick]
      )

    assert snapshot.commands == [%{kind: :async}]
    assert snapshot.subscriptions == [:tick]
    assert Overlay.title() == "Workbench Debug Rail"
    assert History.push([:older, :oldest], :newest, 2) == [:newest, :older]
    assert RenderStats.from_tree(%{flat: [:a, :b]}) == %{entry_count: 2}
    assert RenderStats.from_tree(nil) == %{entry_count: 0}
  end

  test "creates durable session artifact bundles" do
    base_dir =
      Path.join(System.tmp_dir!(), "workbench_devtools_#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(base_dir) end)

    config =
      SessionArtifacts.runtime_config(
        base_dir: base_dir,
        session_label: "Example Session",
        history_limit: 3
      )

    assert config.enabled? == true
    assert config.history_limit == 3
    assert File.exists?(Path.join(config.artifact_dir, "manifest.json"))

    assert :ok = config.sink.(%{kind: :event, entry: %{sequence: 1, trigger: %{kind: :init}}})
    assert :ok = config.sink.(%{kind: :snapshot, entry: %{sequence: 1, route: :home}})

    assert File.exists?(Path.join(config.artifact_dir, "events.jsonl"))
    assert File.exists?(Path.join(config.artifact_dir, "snapshots.jsonl"))
    assert File.exists?(Path.join(config.artifact_dir, "latest.json"))
  end
end
