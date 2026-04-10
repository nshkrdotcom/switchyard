defmodule Switchyard.WorkspaceTest do
  use ExUnit.Case, async: true

  test "exposes the workspace identity marker" do
    assert Switchyard.Workspace.identity() == {:ok, :switchyard_workspace}
  end
end
