defmodule Switchyard.WorkspaceTest do
  use ExUnit.Case, async: true

  alias Switchyard.Workspace.MixProject

  test "exposes the workspace identity marker" do
    assert Switchyard.Workspace.identity() == {:ok, :switchyard_workspace}
  end

  test "exposes the weld release aliases for the internal artifact flow" do
    aliases = MixProject.project()[:aliases]

    assert Keyword.fetch!(aliases, :"weld.release.prepare") == [
             "weld.release.prepare build_support/weld.exs --artifact switchyard"
           ]

    assert Keyword.fetch!(aliases, :"weld.release.track") == [
             "weld.release.track build_support/weld.exs --artifact switchyard"
           ]

    assert Keyword.fetch!(aliases, :"weld.release.archive") == [
             "weld.release.archive build_support/weld.exs --artifact switchyard"
           ]

    assert Keyword.fetch!(aliases, :"release.prepare") == ["weld.release.prepare"]
    assert Keyword.fetch!(aliases, :"release.track") == ["weld.release.track"]
    assert Keyword.fetch!(aliases, :"release.archive") == ["weld.release.archive"]
  end
end
