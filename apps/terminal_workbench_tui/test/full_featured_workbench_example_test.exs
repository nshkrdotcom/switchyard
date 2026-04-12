defmodule Switchyard.FullFeaturedWorkbenchExampleTest do
  use ExUnit.Case, async: false

  test "smoke mode proves the full featured example end to end" do
    repo_root = Path.expand("../../..", __DIR__)

    {output, status} =
      System.cmd("elixir", ["examples/full_featured_workbench.exs", "--smoke"],
        cd: repo_root,
        stderr_to_stdout: true
      )

    assert status == 0
    assert output =~ "smoke ok:"
    assert output =~ "trace="
    assert output =~ "size="
  end

  test "distributed smoke proves the listener-backed example path" do
    repo_root = Path.expand("../../..", __DIR__)

    {output, status} =
      System.cmd(
        "elixir",
        [
          "--sname",
          "switchyard_smoke",
          "--cookie",
          "demo",
          "examples/full_featured_workbench.exs",
          "--distributed-smoke"
        ],
        cd: repo_root,
        stderr_to_stdout: true
      )

    assert status == 0
    assert output =~ "distributed smoke ok:"
    assert output =~ "trace="
    assert output =~ "size=120x36"
  end
end
