defmodule Switchyard.CLI do
  @moduledoc """
  Minimal headless CLI for the Switchyard daemon.
  """

  alias Switchyard.Daemon
  alias Switchyard.Transport.Local

  @type result :: {:ok, term()} | {:error, String.t()}

  @spec main([String.t()]) :: :ok
  def main(argv) do
    opts = runtime_opts()
    :ok = ensure_runtime_started(opts)
    daemon = Keyword.get(opts, :daemon, Switchyard.Daemon.Server)

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

  @doc false
  @spec ensure_runtime_started(keyword()) :: :ok | no_return()
  def ensure_runtime_started(opts \\ []) do
    daemon = Keyword.get(opts, :daemon, Switchyard.Daemon.Server)

    if daemon_running?(daemon) do
      :ok
    else
      start_daemon(opts, daemon)
    end
  end

  defp runtime_opts do
    Application.get_env(:switchyard_cli, :runtime, [])
  end

  defp daemon_running?(daemon) when is_atom(daemon), do: is_pid(Process.whereis(daemon))
  defp daemon_running?(daemon) when is_pid(daemon), do: Process.alive?(daemon)
  defp daemon_running?(_daemon), do: false

  defp start_daemon(opts, daemon) do
    daemon_opts =
      opts
      |> Keyword.take([:store_root])
      |> Keyword.put_new(:site_modules, [Switchyard.Site.Local])
      |> Keyword.put(:name, daemon)

    case Daemon.start_link(daemon_opts) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> exit(reason)
    end
  end

  defp normalize(payload) when is_list(payload), do: Enum.map(payload, &normalize/1)

  defp normalize(%DateTime{} = value), do: DateTime.to_iso8601(value)

  defp normalize(%{__struct__: struct} = payload) when is_atom(struct) do
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
