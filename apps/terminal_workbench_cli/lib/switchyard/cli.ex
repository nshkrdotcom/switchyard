defmodule Switchyard.CLI do
  @moduledoc """
  Minimal headless CLI for the Switchyard daemon.
  """

  alias Switchyard.Daemon
  alias Switchyard.Transport.Local

  @type result :: {:ok, term()} | {:error, String.t()}
  @process_start_switches [
    id: :string,
    label: :string,
    command: :string,
    cwd: :string,
    shell: :boolean,
    clear_env: :boolean,
    pty: :boolean,
    surface_kind: :string,
    target: :string,
    boundary_class: :string,
    ssh_host: :string,
    ssh_port: :integer,
    ssh_user: :string,
    ssh_identity_file: :string,
    sandbox: :string,
    spec_json: :string,
    arg: :keep,
    env: :keep,
    ssh_arg: :keep,
    sandbox_prefix: :keep
  ]

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

  def run(["snapshot"], opts) do
    daemon = Keyword.fetch!(opts, :daemon)
    {:ok, Local.request(daemon, %{kind: :local_snapshot})}
  end

  def run(["process", "start" | argv], opts) do
    daemon = Keyword.fetch!(opts, :daemon)

    case parse_process_start_spec(argv) do
      {:ok, spec} ->
        normalize_start_process_result(Local.request(daemon, %{kind: :start_process, spec: spec}))

      {:error, _message} = error ->
        error
    end
  end

  def run(_argv, _opts) do
    {:error, usage()}
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

  @doc false
  @spec parse_process_start_spec([String.t()]) :: {:ok, map()} | {:error, String.t()}
  def parse_process_start_spec(argv) do
    {opts, _args, invalid} = OptionParser.parse(argv, strict: @process_start_switches)

    cond do
      invalid != [] ->
        {:error, "invalid process start options: #{inspect(invalid)}"}

      spec_json = Keyword.get(opts, :spec_json) ->
        decode_spec_json(spec_json)

      true ->
        build_process_start_spec(opts)
    end
  end

  defp daemon_running?(daemon) when is_atom(daemon), do: is_pid(Process.whereis(daemon))
  defp daemon_running?(daemon) when is_pid(daemon), do: Process.alive?(daemon)
  defp daemon_running?(_daemon), do: false

  defp start_daemon(opts, daemon) do
    daemon_opts =
      opts
      |> Keyword.take([:store_root])
      |> Keyword.put_new(:site_modules, [Switchyard.Site.ExecutionPlane, Switchyard.Site.Jido])
      |> Keyword.put(:name, daemon)

    case Daemon.start_link(daemon_opts) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> exit(reason)
    end
  end

  defp build_process_start_spec(opts) do
    case Keyword.get(opts, :command) do
      nil ->
        {:error, "process start requires --command or --spec-json"}

      command ->
        {:ok,
         %{
           id: Keyword.get(opts, :id),
           label: Keyword.get(opts, :label),
           command: command,
           args: Keyword.get_values(opts, :arg),
           cwd: Keyword.get(opts, :cwd),
           shell?: Keyword.get(opts, :shell, true),
           clear_env?: Keyword.get(opts, :clear_env, false),
           pty?: Keyword.get(opts, :pty, false),
           env: parse_env_pairs(Keyword.get_values(opts, :env)),
           execution_surface: execution_surface_opts(opts),
           sandbox: Keyword.get(opts, :sandbox),
           sandbox_policy: sandbox_policy_opts(opts)
         }
         |> Enum.reject(fn {_key, value} -> is_nil(value) end)
         |> Map.new()}
    end
  end

  defp execution_surface_opts(opts) do
    ssh_host = Keyword.get(opts, :ssh_host)

    surface_kind =
      Keyword.get(opts, :surface_kind, if(ssh_host, do: "ssh_exec", else: "local_subprocess"))

    transport_options =
      []
      |> maybe_put_transport(:host, ssh_host)
      |> maybe_put_transport(:port, Keyword.get(opts, :ssh_port))
      |> maybe_put_transport(:user, Keyword.get(opts, :ssh_user))
      |> maybe_put_transport(:identity_file, Keyword.get(opts, :ssh_identity_file))
      |> maybe_put_transport(:ssh_args, Keyword.get_values(opts, :ssh_arg))

    %{
      surface_kind: surface_kind,
      target_id: Keyword.get(opts, :target, ssh_host),
      boundary_class: Keyword.get(opts, :boundary_class),
      transport_options: transport_options
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == [] end)
    |> Map.new()
  end

  defp sandbox_policy_opts(opts) do
    case Keyword.get_values(opts, :sandbox_prefix) do
      [] -> nil
      prefix -> %{command_prefix: prefix}
    end
  end

  defp parse_env_pairs(values) do
    values
    |> Enum.reduce(%{}, fn pair, acc ->
      case String.split(pair, "=", parts: 2) do
        [key, value] when key != "" -> Map.put(acc, key, value)
        _other -> acc
      end
    end)
  end

  defp maybe_put_transport(opts, _key, nil), do: opts
  defp maybe_put_transport(opts, _key, []), do: opts
  defp maybe_put_transport(opts, key, value), do: Keyword.put(opts, key, value)

  defp decode_spec_json(spec_json) do
    case Jason.decode(spec_json) do
      {:ok, %{} = spec} -> {:ok, spec}
      {:ok, _other} -> {:error, "--spec-json must decode to an object"}
      {:error, reason} -> {:error, "invalid --spec-json: #{Exception.message(reason)}"}
    end
  end

  defp normalize_start_process_result({:ok, payload}), do: {:ok, payload}
  defp normalize_start_process_result({:error, payload}), do: {:error, inspect(payload)}
  defp normalize_start_process_result(other), do: {:error, inspect(other)}

  defp usage do
    "usage: switchyard_cli sites | apps <site-id> | snapshot | process start [--command CMD | --spec-json JSON]"
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
