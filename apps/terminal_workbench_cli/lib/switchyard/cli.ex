defmodule Switchyard.CLI do
  @moduledoc """
  JSON-oriented headless CLI for the Switchyard daemon.

  Commands parse operator input into daemon request maps and print normalized
  JSON. Mutating operations stay behind the daemon action seam; destructive
  process commands require explicit `--confirm`.
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
  @log_switches [
    tail: :integer,
    after_seq: :integer,
    level: :string,
    source_kind: :string,
    process_id: :string,
    job_id: :string
  ]
  @log_level_strings %{
    "debug" => :debug,
    "error" => :error,
    "info" => :info,
    "warn" => :warn,
    "warning" => :warning
  }
  @log_source_kind_strings %{
    "daemon" => :daemon,
    "job" => :job,
    "operator_terminal" => :operator_terminal,
    "process" => :process,
    "site" => :site,
    "stream" => :stream
  }
  @action_run_switches [
    site: :string,
    app: :string,
    resource: :string,
    input_json: :string,
    input: :keep,
    confirm: :boolean
  ]
  @confirm_switches [confirm: :boolean]

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

  def run(["actions"], opts) do
    daemon = Keyword.fetch!(opts, :daemon)
    {:ok, Local.request(daemon, %{kind: :actions})}
  end

  def run(["actions", "--site", site_id], opts) do
    daemon = Keyword.fetch!(opts, :daemon)
    {:ok, Local.request(daemon, %{kind: :actions, site_id: site_id})}
  end

  def run(["actions", site_id], opts) do
    daemon = Keyword.fetch!(opts, :daemon)
    {:ok, Local.request(daemon, %{kind: :actions, site_id: site_id})}
  end

  def run(["action", "run", action_id | argv], opts) do
    daemon = Keyword.fetch!(opts, :daemon)

    with {:ok, request} <- parse_action_run_request(action_id, argv) do
      normalize_action_result(Local.request(daemon, request))
    end
  end

  def run(["snapshot"], opts) do
    daemon = Keyword.fetch!(opts, :daemon)
    {:ok, Local.request(daemon, %{kind: :local_snapshot})}
  end

  def run(["recovery"], opts) do
    daemon = Keyword.fetch!(opts, :daemon)
    snapshot = Local.request(daemon, %{kind: :local_snapshot})
    {:ok, Map.get(snapshot, :recovery_status, %{status: :unknown, warnings: []})}
  end

  def run(["streams"], opts) do
    daemon = Keyword.fetch!(opts, :daemon)
    {:ok, Local.request(daemon, %{kind: :streams})}
  end

  def run(["logs", stream_id | argv], opts) do
    daemon = Keyword.fetch!(opts, :daemon)

    with {:ok, log_opts} <- parse_log_opts(argv) do
      {:ok, Local.request(daemon, Map.merge(%{kind: :logs, stream_id: stream_id}, log_opts))}
    end
  end

  def run(["process", "start" | argv], opts) do
    daemon = Keyword.fetch!(opts, :daemon)

    case parse_process_start_spec(argv) do
      {:ok, spec} ->
        normalize_start_process_result(
          Local.request(daemon, %{
            kind: :execute_action,
            action_id: "execution_plane.process.start",
            site_id: "execution_plane",
            input: spec
          })
        )

      {:error, _message} = error ->
        error
    end
  end

  def run(["process", "list"], opts) do
    daemon = Keyword.fetch!(opts, :daemon)
    snapshot = Local.request(daemon, %{kind: :local_snapshot})
    {:ok, snapshot.processes}
  end

  def run(["process", "inspect", process_id], opts) do
    daemon = Keyword.fetch!(opts, :daemon)
    snapshot = Local.request(daemon, %{kind: :local_snapshot})

    case Enum.find(snapshot.processes, &(&1.id == process_id)) do
      nil -> {:error, "process not found: #{process_id}"}
      process -> {:ok, process}
    end
  end

  def run(["process", "stop", process_id | argv], opts) do
    daemon = Keyword.fetch!(opts, :daemon)

    with :ok <- require_confirm(argv, "process stop") do
      normalize_action_result(
        Local.request(daemon, %{
          kind: :execute_action,
          action_id: "execution_plane.process.stop",
          resource: %{site_id: "execution_plane", kind: :process, id: process_id},
          input: %{"process_id" => process_id},
          confirmed?: true
        })
      )
    end
  end

  def run(["process", "logs", process_id | argv], opts) do
    daemon = Keyword.fetch!(opts, :daemon)

    with {:ok, log_opts} <- parse_log_opts(argv) do
      {:ok,
       Local.request(
         daemon,
         Map.merge(%{kind: :logs, stream_id: "logs/#{process_id}"}, log_opts)
       )}
    end
  end

  def run(["process", "restart", process_id | argv], opts) do
    daemon = Keyword.fetch!(opts, :daemon)

    with :ok <- require_confirm(argv, "process restart") do
      normalize_action_result(
        Local.request(daemon, %{
          kind: :execute_action,
          action_id: "execution_plane.process.restart",
          resource: %{site_id: "execution_plane", kind: :process, id: process_id},
          confirmed?: true
        })
      )
    end
  end

  def run(["process", "signal", process_id, signal], opts) do
    daemon = Keyword.fetch!(opts, :daemon)

    normalize_action_result(
      Local.request(daemon, %{
        kind: :execute_action,
        action_id: "execution_plane.process.signal",
        resource: %{site_id: "execution_plane", kind: :process, id: process_id},
        input: %{"signal" => signal}
      })
    )
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

  defp parse_log_opts(argv) do
    {opts, _args, invalid} = OptionParser.parse(argv, strict: @log_switches)

    if invalid == [] do
      {:ok,
       opts
       |> Enum.map(&normalize_log_opt/1)
       |> Map.new()}
    else
      {:error, "invalid log options: #{inspect(invalid)}"}
    end
  end

  defp parse_action_run_request(action_id, argv) when is_binary(action_id) do
    {opts, args, invalid} = OptionParser.parse(argv, strict: @action_run_switches)

    cond do
      invalid != [] ->
        {:error, "invalid action run options: #{inspect(invalid)}"}

      args != [] ->
        {:error, "unexpected action run arguments: #{inspect(args)}"}

      true ->
        with {:ok, input} <- parse_action_input(opts),
             {:ok, resource} <- parse_resource_ref(Keyword.get(opts, :resource), action_id, opts) do
          request =
            %{
              kind: :execute_action,
              action_id: action_id,
              input: input
            }
            |> maybe_put(:site_id, Keyword.get(opts, :site))
            |> maybe_put(:app_id, Keyword.get(opts, :app))
            |> maybe_put(:resource, resource)
            |> maybe_confirm(Keyword.get(opts, :confirm, false))

          {:ok, request}
        end
    end
  end

  defp parse_action_input(opts) do
    with {:ok, json_input} <- decode_input_json(Keyword.get(opts, :input_json)),
         {:ok, pair_input} <- parse_input_pairs(Keyword.get_values(opts, :input)) do
      {:ok, Map.merge(json_input, pair_input)}
    end
  end

  defp decode_input_json(nil), do: {:ok, %{}}

  defp decode_input_json(input_json) do
    case Jason.decode(input_json) do
      {:ok, %{} = input} -> {:ok, input}
      {:ok, _other} -> {:error, "--input-json must decode to an object"}
      {:error, reason} -> {:error, "invalid --input-json: #{Exception.message(reason)}"}
    end
  end

  defp parse_input_pairs(values) do
    Enum.reduce_while(values, {:ok, %{}}, fn pair, {:ok, acc} ->
      case String.split(pair, "=", parts: 2) do
        [key, value] when key != "" ->
          {:cont, {:ok, Map.put(acc, key, parse_scalar(value))}}

        _other ->
          {:halt, {:error, "--input expects key=value"}}
      end
    end)
  end

  defp parse_scalar("true"), do: true
  defp parse_scalar("false"), do: false

  defp parse_scalar(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _other -> value
    end
  end

  defp parse_resource_ref(nil, _action_id, _opts), do: {:ok, nil}

  defp parse_resource_ref(resource_ref, action_id, opts) when is_binary(resource_ref) do
    resource_ref
    |> String.split(":", parts: 3)
    |> parse_resource_ref_parts(resource_ref, action_id, opts)
  end

  defp parse_resource_ref_parts([site_id, kind, id], _resource_ref, _action_id, _opts)
       when site_id != "" and kind != "" and id != "" do
    {:ok, %{site_id: site_id, kind: kind, id: id}}
  end

  defp parse_resource_ref_parts([kind, id], resource_ref, action_id, opts)
       when kind != "" and id != "" do
    site_id = Keyword.get(opts, :site) || infer_site_id(action_id)

    if is_binary(site_id) and site_id != "" do
      {:ok, %{site_id: site_id, kind: kind, id: id}}
    else
      {:error, "--resource #{resource_ref} requires --site or a site-prefixed action id"}
    end
  end

  defp parse_resource_ref_parts(_parts, _resource_ref, _action_id, _opts) do
    {:error, "--resource must be kind:id or site_id:kind:id"}
  end

  defp infer_site_id(action_id) do
    case String.split(action_id, ".", parts: 2) do
      [site_id, _rest] -> site_id
      _other -> nil
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_confirm(map, true), do: Map.put(map, :confirmed?, true)
  defp maybe_confirm(map, _confirmed?), do: map

  defp require_confirm(argv, command_name) do
    {opts, args, invalid} = OptionParser.parse(argv, strict: @confirm_switches)

    cond do
      invalid != [] ->
        {:error, "invalid #{command_name} options: #{inspect(invalid)}"}

      args != [] ->
        {:error, "unexpected #{command_name} arguments: #{inspect(args)}"}

      Keyword.get(opts, :confirm, false) ->
        :ok

      true ->
        {:error, "#{command_name} requires --confirm"}
    end
  end

  defp normalize_log_opt({:level, value}) when is_binary(value),
    do: {:level, Map.get(@log_level_strings, value, value)}

  defp normalize_log_opt({:source_kind, value}) when is_binary(value),
    do: {:source_kind, Map.get(@log_source_kind_strings, value, value)}

  defp normalize_log_opt(opt), do: opt

  defp normalize_start_process_result({:ok, payload}), do: {:ok, payload}
  defp normalize_start_process_result({:error, payload}), do: {:error, inspect(payload)}
  defp normalize_start_process_result(other), do: {:error, inspect(other)}

  defp normalize_action_result({:ok, payload}), do: {:ok, payload}
  defp normalize_action_result({:error, payload}), do: {:error, inspect(payload)}
  defp normalize_action_result(other), do: {:error, inspect(other)}

  defp usage do
    "usage: switchyard_cli sites | apps <site-id> | actions [site-id|--site <site-id>] | action run <action-id> [--site <site-id>] [--resource kind:id] [--input-json JSON] [--confirm] | snapshot | recovery | streams | logs <stream-id> | process start|list|inspect|stop|restart|signal|logs"
  end

  defp normalize(payload) when is_list(payload), do: Enum.map(payload, &normalize/1)

  defp normalize(payload) when is_tuple(payload), do: payload |> Tuple.to_list() |> normalize()

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
