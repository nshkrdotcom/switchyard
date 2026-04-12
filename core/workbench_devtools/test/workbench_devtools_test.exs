defmodule WorkbenchDevtoolsTest do
  use ExUnit.Case, async: true

  alias Workbench.Devtools.{Inspector, Overlay, RenderStats}

  test "builds an inspectable snapshot" do
    snapshot = Inspector.snapshot(commands: [%{kind: :async}], subscriptions: [:tick])

    assert snapshot.commands == [%{kind: :async}]
    assert snapshot.subscriptions == [:tick]
    assert Overlay.title() == "Workbench Inspector"
    assert RenderStats.from_tree(%{flat: [:a, :b]}) == %{entry_count: 2}
    assert RenderStats.from_tree(nil) == %{entry_count: 0}
  end
end
