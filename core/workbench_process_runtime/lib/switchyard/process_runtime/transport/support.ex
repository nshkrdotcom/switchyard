defmodule Switchyard.ProcessRuntime.Transport.Support do
  @moduledoc false

  @spec shell_escape(String.t()) :: String.t()
  def shell_escape(value) when is_binary(value) do
    "'" <> String.replace(value, "'", "'\"'\"'") <> "'"
  end

  @spec shell_join([String.t()]) :: String.t()
  def shell_join(argv) when is_list(argv) do
    Enum.map_join(argv, " ", &shell_escape/1)
  end

  @spec env_assignments(%{optional(String.t()) => String.t()}) :: [String.t()]
  def env_assignments(env) when is_map(env) do
    Enum.map(env, fn {key, value} -> "#{key}=#{shell_escape(value)}" end)
  end

  @spec resolve_executable(String.t(), String.t()) :: String.t()
  def resolve_executable(name, fallback) when is_binary(name) and is_binary(fallback) do
    System.find_executable(name) || fallback
  end
end
