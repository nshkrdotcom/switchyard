defmodule Switchyard.TUI.Theme do
  @moduledoc false

  @default %{
    accent: :cyan,
    muted: :dark_gray,
    success: :green,
    warning: :yellow,
    danger: :light_red,
    surface: :white,
    surface_alt: :gray,
    focus: :light_cyan
  }

  @spec default() :: map()
  def default, do: @default
end
