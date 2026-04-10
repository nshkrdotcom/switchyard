defmodule Switchyard.Transport.Local do
  @moduledoc """
  In-VM local transport that speaks to a daemon-like GenServer.
  """

  @spec request(GenServer.server(), term()) :: term()
  def request(server, payload) do
    GenServer.call(server, {:switchyard_request, payload})
  end

  @spec notify(GenServer.server(), term()) :: :ok
  def notify(server, payload) do
    GenServer.cast(server, {:switchyard_notify, payload})
  end
end
