defmodule Switchyard.TUI.Keymap do
  @moduledoc false

  alias ExRatatui.Event
  alias Switchyard.TUI.Model

  @spec to_msg(Event.Key.t(), Model.t()) :: :ignore | {:msg, term()}
  def to_msg(%Event.Key{code: "q", modifiers: ["ctrl"]}, _state), do: {:msg, :quit}

  def to_msg(%Event.Key{} = event, %Model{} = state) do
    case delegated_msg(event, state) do
      :ignore -> default_msg(event)
      other -> other
    end
  end

  defp delegated_msg(%Event.Key{} = event, %Model{} = state) do
    case {state.shell.route, Model.current_mount_module(state)} do
      {:app, nil} ->
        :ignore

      {:app, module} ->
        module.event_to_msg(event, state, Model.current_mount_state(state))

      _other ->
        :ignore
    end
  end

  defp default_msg(%Event.Key{code: "up"}), do: {:msg, :select_prev}
  defp default_msg(%Event.Key{code: "down"}), do: {:msg, :select_next}
  defp default_msg(%Event.Key{code: "enter"}), do: {:msg, :enter}
  defp default_msg(%Event.Key{code: "esc"}), do: {:msg, :back}
  defp default_msg(%Event.Key{}), do: :ignore
end
