defmodule Switchyard.TUI do
  @moduledoc """
  Framework-backed terminal host entrypoint.
  """

  alias ExecutionPlane.OperatorTerminal
  alias Switchyard.Contracts.GovernedRouteAuthority
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
  @governed_operator_direct_fields [
    :auth_methods,
    :boundary_class,
    :daemon,
    :daemon_starter,
    :daemon_stopper,
    :observability,
    :port,
    :surface_ref,
    :transport,
    :user_passwords
  ]

  @spec initial_shell_state() :: Shell.State.t()
  def initial_shell_state, do: Shell.new()

  @spec run(keyword()) :: :ok | {:error, term()}
  def run(opts \\ []) do
    with {:ok, opts} <- apply_governed_operator_authority(opts),
         :ok <- ensure_operator_terminal_runtime(),
         {:ok, opts} <- runtime_opts(opts),
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

  defp ensure_operator_terminal_runtime do
    case Application.ensure_all_started(:execution_plane_operator_terminal) do
      {:ok, _started_apps} -> :ok
      {:error, reason} -> {:error, {:operator_terminal_boot_failed, reason}}
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
    Local.request(daemon, %{
      kind: :execute_action,
      action_id: "execution_plane.process.start",
      site_id: "execution_plane",
      input: attrs
    })
  end

  defp request_handler(daemon, {:logs, stream_id}, _opts) when is_binary(stream_id) do
    Local.request(daemon, %{kind: :logs, stream_id: stream_id})
  end

  defp request_handler(daemon, {:logs, stream_id, log_opts}, _opts) when is_binary(stream_id) do
    Local.request(daemon, Map.merge(%{kind: :logs, stream_id: stream_id}, Map.new(log_opts)))
  end

  defp request_handler(daemon, %{kind: :execute_action} = payload, _opts) do
    Local.request(daemon, payload)
  end

  defp request_handler(daemon, :streams, opts) do
    case Keyword.get(opts, :resource) do
      nil -> Local.request(daemon, %{kind: :streams})
      resource -> Local.request(daemon, %{kind: :streams, resource: resource})
    end
  end

  defp request_handler(_daemon, request, _opts) do
    {:error, {:unknown_request, request}}
  end

  defp apply_governed_operator_authority(opts) do
    case Keyword.get(opts, :governed_authority) do
      nil -> {:ok, opts}
      authority_attrs -> materialize_governed_operator_authority(opts, authority_attrs)
    end
  end

  defp materialize_governed_operator_authority(opts, authority_attrs) do
    case find_governed_operator_direct_field(opts) do
      nil -> merge_governed_operator_authority(opts, authority_attrs)
      field -> {:error, {:unmanaged_governed_field, field}}
    end
  end

  defp merge_governed_operator_authority(opts, authority_attrs) do
    with {:ok, authority} <- GovernedRouteAuthority.new(authority_attrs) do
      {:ok,
       opts
       |> Keyword.delete(:governed_authority)
       |> Keyword.merge(GovernedRouteAuthority.operator_terminal_opts(authority))}
    end
  end

  defp find_governed_operator_direct_field(opts) do
    Enum.find(@governed_operator_direct_fields, &Keyword.has_key?(opts, &1))
  end
end
