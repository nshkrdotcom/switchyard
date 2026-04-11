defmodule Switchyard.TUI.Command do
  @moduledoc """
  Small wrapper around the underlying terminal runtime command helpers.
  """

  alias ExRatatui.Command

  @spec async((-> term()), (term() -> term())) :: Command.t()
  def async(run_fun, map_fun) when is_function(run_fun, 0) and is_function(map_fun, 1) do
    Command.async(run_fun, map_fun)
  end
end
