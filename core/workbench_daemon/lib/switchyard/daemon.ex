defmodule Switchyard.Daemon do
  @moduledoc """
  Local control-plane daemon API.

  The daemon is the authority for local Switchyard process, job, stream, log,
  action, snapshot, and recovery state. Clients should use these functions or
  the `%{kind: ...}` request envelope instead of mutating runtime packages
  directly.
  """

  alias Switchyard.Daemon.Server

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id:
        Keyword.get(opts, :id) || Keyword.get(opts, :name) ||
          {Server, System.unique_integer([:positive])},
      start: {Server, :start_link, [opts]}
    }
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    Server.start_link(opts)
  end

  @spec list_sites(GenServer.server()) :: [Switchyard.Contracts.SiteDescriptor.t()]
  def list_sites(server), do: GenServer.call(server, :list_sites)

  @spec list_apps(GenServer.server(), String.t()) :: [Switchyard.Contracts.AppDescriptor.t()]
  def list_apps(server, site_id), do: GenServer.call(server, {:list_apps, site_id})

  @spec actions(GenServer.server()) :: [Switchyard.Contracts.Action.t()]
  def actions(server), do: GenServer.call(server, {:switchyard_request, %{kind: :actions}})

  @spec execute_action(GenServer.server(), map()) ::
          {:ok, Switchyard.Contracts.ActionResult.t()} | {:error, term()}
  def execute_action(server, attrs) when is_map(attrs) do
    GenServer.call(server, {:switchyard_request, Map.put(attrs, :kind, :execute_action)})
  end

  @spec snapshot(GenServer.server()) :: map()
  def snapshot(server), do: GenServer.call(server, :snapshot)

  @spec start_process(GenServer.server(), map()) ::
          {:ok, Switchyard.Contracts.ActionResult.t()} | {:error, term()}
  def start_process(server, attrs), do: GenServer.call(server, {:start_process, attrs})

  @spec stop_process(GenServer.server(), String.t()) ::
          {:ok, Switchyard.Contracts.ActionResult.t()} | {:error, term()}
  def stop_process(server, process_id), do: GenServer.call(server, {:stop_process, process_id})

  @spec logs(GenServer.server(), String.t()) :: [Switchyard.Contracts.LogEvent.t()]
  def logs(server, stream_id), do: GenServer.call(server, {:logs, stream_id})
end
