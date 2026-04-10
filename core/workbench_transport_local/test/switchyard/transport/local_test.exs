defmodule Switchyard.Transport.LocalTest do
  use ExUnit.Case, async: true

  alias Switchyard.Transport.Local

  defmodule FakeServer do
    use GenServer

    def start_link(test_pid) do
      GenServer.start_link(__MODULE__, test_pid)
    end

    def init(test_pid), do: {:ok, test_pid}

    def handle_call({:switchyard_request, payload}, _from, test_pid) do
      send(test_pid, {:request_payload, payload})
      {:reply, {:ok, payload}, test_pid}
    end

    def handle_cast({:switchyard_notify, payload}, test_pid) do
      send(test_pid, {:notify_payload, payload})
      {:noreply, test_pid}
    end
  end

  test "forwards synchronous requests" do
    {:ok, server} = FakeServer.start_link(self())

    assert {:ok, %{kind: :sites}} = Local.request(server, %{kind: :sites})
    assert_receive {:request_payload, %{kind: :sites}}
  end

  test "forwards notifications" do
    {:ok, server} = FakeServer.start_link(self())

    assert :ok = Local.notify(server, %{kind: :refresh})
    assert_receive {:notify_payload, %{kind: :refresh}}
  end
end
