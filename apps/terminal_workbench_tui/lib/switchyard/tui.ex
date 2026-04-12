defmodule Switchyard.TUI do
  @moduledoc """
  Framework-backed terminal host entrypoint.
  """

  alias Switchyard.Shell
  alias Switchyard.TUI.App

  @spec initial_shell_state() :: Shell.State.t()
  def initial_shell_state, do: Shell.new()

  @spec run(keyword()) :: :ok | {:error, term()}
  def run(opts \\ []) do
    case App.start_link(opts) do
      {:ok, pid} ->
        ref = Process.monitor(pid)

        receive do
          {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
