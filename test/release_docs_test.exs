defmodule Switchyard.ReleaseDocsTest do
  use ExUnit.Case, async: true

  @docs [
    Path.expand("../README.md", __DIR__),
    Path.expand("../guides/workspace_workflow.md", __DIR__),
    Path.expand("../guides/testing_and_delivery.md", __DIR__),
    Path.expand("../guides/current_state.md", __DIR__),
    Path.expand("../docs/implementation_checklist.md", __DIR__)
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

      assert doc =~ "projection/switchyard_foundation",
             "#{path} must describe the projection branch explicitly"

      refute doc =~ "WELD_PATH",
             "#{path} must not describe committed Weld path overrides anymore"

      refute doc =~ "WELD_GIT_REF",
             "#{path} must not describe committed Weld git-ref overrides anymore"

      refute doc =~ "keeps `hex.build` enabled",
             "#{path} must not describe the removed pre-0.7.0 tarball workaround"

      refute doc =~ "deterministic tarball for bundle and projection tracking",
             "#{path} must not describe tarball-backed tracking as required anymore"
    end)
  end

  defp normalize_whitespace(text), do: String.replace(text, ~r/\s+/, " ")
end
