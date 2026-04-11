defmodule Switchyard.TUI.Mount do
  @moduledoc """
  Behaviour for externally mounted TUI apps hosted inside the generic
  Switchyard terminal shell.
  """

  alias ExRatatui.Event
  alias ExRatatui.Frame
  alias Switchyard.TUI.Model

  @callback id() :: String.t()
  @callback init(keyword()) :: term()
  @callback open(Model.t(), term()) :: {Model.t(), term(), [term()]}
  @callback event_to_msg(Event.Key.t(), Model.t(), term()) :: :ignore | {:msg, term()}
  @callback update(term(), Model.t(), term()) :: {Model.t(), term(), [term()]} | :unhandled
  @callback render(Model.t(), Frame.t(), term()) :: list()
end
