defmodule Switchyard.CLI do
  @moduledoc """
  Minimal headless CLI for the Switchyard daemon.
  """

  alias Switchyard.Transport.Local

  @type result :: {:ok, term()} | {:error, String.t()}

  @spec main([String.t()]) :: :ok
  def main(argv) do
    daemon = Keyword.get(runtime_opts(), :daemon, Switchyard.Daemon.Server)

    case run(argv, daemon: daemon) do
      {:ok, payload} ->
        payload
        |> normalize()
        |> Jason.encode!(pretty: true)
        |> IO.puts()

      {:error, message} ->
        IO.puts(:stderr, message)
        System.halt(1)
    end
  end

  @spec run([String.t()], keyword()) :: result()
  def run(["sites"], opts) do
    daemon = Keyword.fetch!(opts, :daemon)
    {:ok, Local.request(daemon, %{kind: :sites})}
  end

  def run(["apps", site_id], opts) do
    daemon = Keyword.fetch!(opts, :daemon)
    {:ok, Local.request(daemon, %{kind: :apps, site_id: site_id})}
  end

  def run(["local", "snapshot"], opts) do
    daemon = Keyword.fetch!(opts, :daemon)
    {:ok, Local.request(daemon, %{kind: :local_snapshot})}
  end

  def run(_argv, _opts) do
    {:error, "usage: switchyard_cli sites | apps <site-id> | local snapshot"}
  end

  defp runtime_opts do
    Application.get_env(:switchyard_cli, :runtime, [])
  end

  defp normalize(payload) when is_list(payload), do: Enum.map(payload, &normalize/1)

  defp normalize(%DateTime{} = value), do: DateTime.to_iso8601(value)

  defp normalize(%{__struct__: struct} = payload) do
    payload
    |> Map.from_struct()
    |> Map.put(:__struct__, inspect(struct))
    |> normalize()
  end

  defp normalize(payload) when is_map(payload) do
    Enum.into(payload, %{}, fn {key, value} -> {to_string(key), normalize(value)} end)
  end

  defp normalize(payload), do: payload
end
