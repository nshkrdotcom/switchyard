defmodule Switchyard.ProcessRuntime.Transport.ManagedProcess do
  @moduledoc false
  use GenServer

  alias ExecutionPlane.Process.Transport
  alias ExecutionPlane.Process.Transport.Error
  alias ExecutionPlane.ProcessExit

  @spec start_link({Switchyard.ProcessRuntime.t(), pid(), map()}) :: GenServer.on_start()
  def start_link({spec, sink_pid, plan})
      when is_map(spec) and is_binary(spec.id) and is_pid(sink_pid) and is_map(plan) do
    GenServer.start(__MODULE__, {spec, sink_pid, plan})
  end

  @impl true
  def init({spec, sink_pid, plan}) do
    Process.flag(:trap_exit, true)

    case start_transport(plan) do
      {:ok, transport} ->
        {:ok,
         %{
           buffer: "",
           stderr_buffer: "",
           plan: plan,
           sink_pid: sink_pid,
           spec: spec,
           transport: transport
         }}

      {:error, {:transport, %Error{} = error}} ->
        {:stop, error.reason}
    end
  end

  @impl true
  def handle_info({:transport_message, line}, state) when is_binary(line) do
    send(state.sink_pid, {:process_output, state.spec.id, line})
    {:noreply, state}
  end

  def handle_info({:transport_data, data}, state) when is_binary(data) do
    {lines, buffer} = split_lines(state.buffer <> data)

    Enum.each(lines, fn line ->
      send(state.sink_pid, {:process_output, state.spec.id, line})
    end)

    {:noreply, %{state | buffer: buffer}}
  end

  def handle_info({:transport_stderr, data}, state) when is_binary(data) do
    {lines, stderr_buffer} = split_lines(state.stderr_buffer <> data)

    Enum.each(lines, fn line ->
      send(state.sink_pid, {:process_output, state.spec.id, line})
    end)

    {:noreply, %{state | stderr_buffer: stderr_buffer}}
  end

  def handle_info({:transport_error, %Error{} = error}, state) do
    send(state.sink_pid, {:process_output, state.spec.id, error.message})
    {:noreply, state}
  end

  def handle_info({:transport_exit, %ProcessExit{} = exit}, state) do
    flush_buffers(state)
    send(state.sink_pid, {:process_exit, state.spec.id, exit.code || 1})
    {:stop, :normal, clear_buffers(state)}
  end

  def handle_info({:EXIT, transport, _reason}, %{transport: transport} = state) do
    {:stop, :normal, state}
  end

  @impl true
  def terminate(_reason, %{transport: transport}) when is_pid(transport) do
    Transport.close(transport)
  end

  def terminate(_reason, _state), do: :ok

  defp start_transport(plan) do
    Transport.start_link(
      command: plan.command,
      execution_surface: %{
        surface_kind: plan.surface_kind,
        target_id: plan.target_id,
        surface_ref: plan.surface_ref,
        boundary_class: plan.boundary_class,
        observability: plan.observability,
        transport_options: plan.transport_options
      },
      pty?: Map.get(plan, :pty?, false),
      subscriber: self()
    )
  end

  defp flush_buffers(state) do
    if state.buffer != "" do
      send(state.sink_pid, {:process_output, state.spec.id, state.buffer})
    end

    if state.stderr_buffer != "" do
      send(state.sink_pid, {:process_output, state.spec.id, state.stderr_buffer})
    end
  end

  defp clear_buffers(state), do: %{state | buffer: "", stderr_buffer: ""}

  defp split_lines(data) do
    parts = String.split(data, "\n", trim: false)

    case List.pop_at(parts, -1) do
      {buffer, lines} -> {Enum.reject(lines, &(&1 == "")), buffer}
    end
  end
end
