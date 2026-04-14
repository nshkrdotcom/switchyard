defmodule Switchyard.WorkspaceTest do
  use ExUnit.Case, async: true

  alias Switchyard.Workspace.MixProject

  test "exposes the workspace identity marker" do
    assert Switchyard.Workspace.identity() == {:ok, :switchyard_workspace}
  end

  test "uses Weld task autodiscovery instead of manifest-forwarding aliases" do
    aliases = MixProject.project()[:aliases]

    for alias_name <- [
          :"weld.inspect",
          :"weld.graph",
          :"weld.project",
          :"weld.verify",
          :"weld.release.prepare",
          :"weld.release.track",
          :"weld.release.archive",
          :"release.prepare",
          :"release.track",
          :"release.archive"
        ] do
      refute Keyword.has_key?(aliases, alias_name),
             "expected #{inspect(alias_name)} to be unnecessary on Weld 0.7.1"
    end
  end

  test "uses the released Weld 0.7.1 line directly" do
    assert {:weld, "~> 0.7.1", runtime: false} in MixProject.project()[:deps]
  end
end
