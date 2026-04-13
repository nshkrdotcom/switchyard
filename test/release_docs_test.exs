defmodule Switchyard.ReleaseDocsTest do
  use ExUnit.Case, async: true

  @docs [
    Path.expand("../README.md", __DIR__),
    Path.expand("../guides/workspace_workflow.md", __DIR__),
    Path.expand("../guides/testing_and_delivery.md", __DIR__)
  ]

  test "delivery docs describe the internal welded projection flow" do
    Enum.each(@docs, fn path ->
      doc = path |> File.read!() |> normalize_whitespace()

      assert doc =~ "mix release.prepare",
             "#{path} must describe bundle preparation explicitly"

      assert doc =~ "mix release.track",
             "#{path} must describe projection tracking explicitly"

      assert doc =~ "mix release.archive",
             "#{path} must describe bundle archival explicitly"

      assert doc =~ "WELD_PATH=../weld",
             "#{path} must describe local sibling-weld development explicitly"

      assert doc =~ "WELD_GIT_REF",
             "#{path} must describe pinned unreleased weld usage explicitly"
    end)
  end

  defp normalize_whitespace(text), do: String.replace(text, ~r/\s+/, " ")
end
