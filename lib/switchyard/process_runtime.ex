defmodule Switchyard.ProcessRuntime do
  @moduledoc """
  Minimal managed local process runtime built on ports.
  """

  defmodule Spec do
    @moduledoc "Specification for a managed process."

    @enforce_keys [:id, :command]
    defstruct id: nil, command: nil, cwd: nil, env: %{}

    @type t :: %__MODULE__{
            id: String.t(),
            command: String.t(),
            cwd: String.t() | nil,
            env: %{optional(String.t()) => String.t()}
          }
  end

  defmodule ManagedProcess do
    @moduledoc false
    use GenServer

    alias Switchyard.ProcessRuntime.Spec

    @spec start_link({Spec.t(), pid()}) :: GenServer.on_start()
    def start_link({%Spec{} = spec, sink_pid}) when is_pid(sink_pid) do
      GenServer.start_link(__MODULE__, {spec, sink_pid})
    end

    @impl true
    def init({%Spec{} = spec, sink_pid}) do
      executable = System.find_executable("sh") || "/bin/sh"

      port =
        Port.open({:spawn_executable, executable}, [
          :binary,
          :exit_status,
          :stderr_to_stdout,
          args: ["-lc", spec.command],
          cd: spec.cwd || File.cwd!(),
          env: Enum.into(spec.env, [])
        ])

      {:ok, %{buffer: "", port: port, sink_pid: sink_pid, spec: spec}}
    end

    @impl true
    def handle_info({port, {:data, data}}, %{port: port} = state) do
      {lines, buffer} = split_lines(state.buffer <> data)

      Enum.each(lines, fn line ->
        send(state.sink_pid, {:process_output, state.spec.id, line})
      end)

      {:noreply, %{state | buffer: buffer}}
    end

    @impl true
    def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
      if state.buffer != "" do
        send(state.sink_pid, {:process_output, state.spec.id, state.buffer})
      end

      send(state.sink_pid, {:process_exit, state.spec.id, status})
      {:stop, :normal, %{state | buffer: ""}}
    end

    defp split_lines(data) do
      parts = String.split(data, "\n", trim: false)

      case List.pop_at(parts, -1) do
        {buffer, lines} -> {Enum.reject(lines, &(&1 == "")), buffer}
      end
    end
  end

  @spec spec!(map()) :: Spec.t()
  def spec!(attrs) when is_map(attrs) do
    struct!(Spec, attrs)
  end

  @spec start_managed(Spec.t(), pid()) :: GenServer.on_start()
  def start_managed(%Spec{} = spec, sink_pid) when is_pid(sink_pid) do
    ManagedProcess.start_link({spec, sink_pid})
  end

  @spec preview_command(Spec.t()) :: String.t()
  def preview_command(%Spec{} = spec), do: spec.command
end
