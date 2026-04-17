defmodule Switchyard.ProcessRuntime.Transport do
  @moduledoc false

  alias Switchyard.ProcessRuntime
  alias Switchyard.ProcessRuntime.Transport.{Local, ManagedProcess, SSHExec}

  @type adapter :: Local | SSHExec

  @spec start_managed(ProcessRuntime.t(), pid()) :: GenServer.on_start()
  def start_managed(spec, sink_pid) when is_map(spec) and is_pid(sink_pid) do
    with {:ok, adapter} <- adapter(spec),
         :ok <- adapter.validate(spec),
         {:ok, plan} <- adapter.command_plan(spec) do
      ManagedProcess.start_link({spec, sink_pid, plan})
    end
  end

  @spec preview_command(ProcessRuntime.t()) :: String.t()
  def preview_command(spec) when is_map(spec) do
    case adapter(spec) do
      {:ok, adapter} -> preview_from_adapter(adapter, spec)
      {:error, reason} -> invalid_command(reason)
    end
  end

  @spec adapter(ProcessRuntime.t()) :: {:ok, module()} | {:error, term()}
  def adapter(%{execution_surface: %{surface_kind: :local_subprocess}}), do: {:ok, Local}
  def adapter(%{execution_surface: %{surface_kind: :ssh_exec}}), do: {:ok, SSHExec}

  def adapter(%{execution_surface: %{surface_kind: surface_kind}}),
    do: {:error, {:unsupported_surface_kind, surface_kind}}

  defp preview_from_adapter(adapter, spec) when is_map(spec) do
    if function_exported?(adapter, :preview_command, 1) do
      adapter.preview_command(spec)
    else
      preview_from_plan(adapter.command_plan(spec))
    end
  end

  defp preview_from_plan({:ok, %{description: description}}), do: description
  defp preview_from_plan({:error, reason}), do: invalid_command(reason)

  defp invalid_command(reason), do: "invalid command: #{inspect(reason)}"
end
