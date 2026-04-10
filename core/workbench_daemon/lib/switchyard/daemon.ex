defmodule Switchyard.Daemon do
  @moduledoc """
  Local control-plane daemon API.
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
