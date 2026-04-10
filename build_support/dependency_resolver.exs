defmodule Switchyard.Build.DependencyResolver do
  @moduledoc false

  @repo_root Path.expand("..", __DIR__)

  def blitz(opts \\ []) do
    resolve_external(
      :blitz,
      local_root_path("BLITZ_PATH", "../blitz"),
      "~> 0.2.0",
      opts
    )
  end

  def weld(opts \\ []) do
    resolve_external(
      :weld,
      local_root_path("WELD_PATH", "../weld"),
      "~> 0.4.0",
      opts
    )
  end

  def repo_root, do: @repo_root

  defp resolve_external(app, path, requirement, opts) do
    case existing_path(path) do
      nil -> {app, requirement, opts}
      resolved_path -> {app, Keyword.merge([path: resolved_path], opts)}
    end
  end

  defp local_root_path(env_var, default_relative_path) do
    case System.get_env(env_var) do
      nil ->
        default_relative_path
        |> Path.expand(@repo_root)
        |> existing_path()

      value when value in ["", "0", "false", "disabled"] ->
        nil

      value ->
        value
        |> Path.expand(@repo_root)
        |> existing_path()
    end
  end

  defp existing_path(nil), do: nil

  defp existing_path(path) do
    expanded_path = Path.expand(path)

    if File.dir?(expanded_path) do
      expanded_path
    else
      nil
    end
  end
end
