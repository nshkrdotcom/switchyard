defmodule Switchyard.TUI do
  @moduledoc """
  Framework-backed terminal host entrypoint.
  """

  alias ExecutionPlane.OperatorTerminal
  alias Switchyard.Daemon
  alias Switchyard.Shell
  alias Switchyard.Transport.Local
  alias Switchyard.TUI.App

  @runtime_option_keys [
    :daemon,
    :site_modules,
    :snapshot,
    :request_handler,
    :open_app,
    :debug,
    :debug_dir,
    :debug_history_limit,
    :test_mode,
    :log_level,
    :store_root
  ]
  @operator_terminal_surface_option_keys [:surface_ref, :boundary_class, :observability]

  @spec initial_shell_state() :: Shell.State.t()
  def initial_shell_state, do: Shell.new()

  @spec run(keyword()) :: :ok | {:error, term()}
  def run(opts \\ []) do
    with {:ok, opts} <- runtime_opts(opts),
         {:ok, pid} <- start_operator_terminal(opts) do
      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp runtime_opts(opts) do
    if Keyword.has_key?(opts, :request_handler) do
      {:ok, opts}
    else
      with {:ok, daemon} <- ensure_daemon(opts),
           snapshot <- Local.request(daemon, %{kind: :local_snapshot}) do
        {:ok,
         opts
         |> Keyword.put_new(:daemon, daemon)
         |> Keyword.put_new(:site_modules, [Switchyard.Site.ExecutionPlane, Switchyard.Site.Jido])
         |> Keyword.put_new(:snapshot, snapshot)
         |> Keyword.put_new(:request_handler, &request_handler(daemon, &1, &2))}
      end
    end
  end

  defp ensure_daemon(opts) do
    case Keyword.get(opts, :daemon) do
      daemon when is_pid(daemon) ->
        {:ok, daemon}

      daemon when is_atom(daemon) ->
        case Process.whereis(daemon) do
          pid when is_pid(pid) -> {:ok, pid}
          nil -> start_daemon(opts, daemon)
        end

      daemon_name ->
        start_daemon(opts, daemon_name)
    end
  end

  defp start_daemon(opts, daemon_name) do
    Daemon.start_link(
      site_modules:
        Keyword.get(opts, :site_modules, [Switchyard.Site.ExecutionPlane, Switchyard.Site.Jido]),
      store_root: Keyword.get(opts, :store_root),
      name: daemon_name
    )
  end

  defp start_operator_terminal(opts) do
    {surface_kind, surface_opts, transport_options} = operator_terminal_surface(opts)

    [
      mod: App,
      app_opts: Keyword.take(opts, @runtime_option_keys),
      surface_kind: surface_kind,
      transport_options: transport_options
    ]
    |> maybe_put_operator_terminal_opt(:surface_ref, Keyword.get(surface_opts, :surface_ref))
    |> maybe_put_operator_terminal_opt(
      :boundary_class,
      Keyword.get(surface_opts, :boundary_class)
    )
    |> maybe_put_operator_terminal_opt(:observability, Keyword.get(surface_opts, :observability))
    |> OperatorTerminal.start_link()
  end

  defp operator_terminal_surface(opts) do
    transport = Keyword.get(opts, :transport, :local)

    {surface_opts, transport_options} =
      opts
      |> Keyword.drop(@runtime_option_keys ++ [:transport])
      |> Keyword.split(@operator_terminal_surface_option_keys)

    surface_opts = Enum.reject(surface_opts, fn {_key, value} -> is_nil(value) end)
    transport_options = Enum.reject(transport_options, fn {_key, value} -> is_nil(value) end)

    case transport do
      :ssh -> {:ssh_terminal, surface_opts, transport_options}
      :distributed -> {:distributed_terminal, surface_opts, transport_options}
      _other -> {:local_terminal, surface_opts, transport_options}
    end
  end

  defp maybe_put_operator_terminal_opt(opts, _key, nil), do: opts
  defp maybe_put_operator_terminal_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp request_handler(daemon, :local_snapshot, _opts) do
    Local.request(daemon, %{kind: :local_snapshot})
  end

  defp request_handler(daemon, {:start_process, attrs}, _opts) when is_map(attrs) do
    Local.request(daemon, %{kind: :start_process, spec: attrs})
  end

  defp request_handler(daemon, {:logs, stream_id}, _opts) when is_binary(stream_id) do
    Local.request(daemon, %{kind: :logs, stream_id: stream_id})
  end

  defp request_handler(_daemon, request, _opts) do
    {:error, {:unknown_request, request}}
  end
end
