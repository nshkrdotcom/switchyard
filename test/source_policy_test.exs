defmodule Switchyard.SourcePolicyTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("..", __DIR__)
  @source_roots [
    "mix.exs",
    "dialyzer.ignore.exs",
    "build_support/**/*.exs",
    "lib/**/*.ex",
    "test/**/*.exs",
    "core/**/*.ex",
    "core/**/*.exs",
    "sites/**/*.ex",
    "sites/**/*.exs",
    "apps/**/*.ex",
    "apps/**/*.exs",
    "examples/**/*.ex",
    "examples/**/*.exs"
  ]
  @excluded_segments ["deps", "_build", "dist", "doc", "tmp", "node_modules"]

  test "source uses bounded atoms and fixed string parsing" do
    violations =
      @source_roots
      |> Enum.flat_map(&Path.wildcard(Path.join(@repo_root, &1)))
      |> Enum.uniq()
      |> Enum.reject(&excluded_path?/1)
      |> Enum.flat_map(&violations_for_file/1)
      |> Enum.sort()

    assert violations == []
  end

  defp violations_for_file(path) do
    contents = File.read!(path)

    forbidden_tokens()
    |> Enum.filter(fn {_label, token} -> String.contains?(contents, token) end)
    |> Enum.map(fn {label, _token} ->
      "#{Path.relative_to(path, @repo_root)} contains #{label}"
    end)
  end

  defp forbidden_tokens do
    [
      {join(["String", ".to_", "atom"]), join(["String", ".to_", "atom"])},
      {join(["binary_to_", "atom"]), join(["binary_to_", "atom"])},
      {join(["to_existing_", "atom"]), join(["to_existing_", "atom"])},
      {join(["list_to_", "atom"]), join(["list_to_", "atom"])},
      {join(["binary_to_existing_", "atom"]), join(["binary_to_existing_", "atom"])},
      {join([":\"", "#", "{"]), join([":\"", "#", "{"])},
      {join(["Reg", "ex"]), join(["Reg", "ex"])},
      {join(["~", "r"]), join(["~", "r"])},
      {join([":", "re."]), join([":", "re."])},
      {join(["String", ".match"]), join(["String", ".match"])},
      {join(["Reg", "Exp"]), join(["Reg", "Exp"])},
      {join(["reg", "exp"]), join(["reg", "exp"])},
      {join(["re", ".compile"]), join(["re", ".compile"])},
      {join(["import ", "re"]), join(["import ", "re"])}
    ]
  end

  defp join(parts), do: Enum.join(parts)

  defp excluded_path?(path) do
    relative = Path.relative_to(path, @repo_root)
    relative_segments = Path.split(relative)

    Enum.any?(@excluded_segments, &(&1 in relative_segments))
  end
end
