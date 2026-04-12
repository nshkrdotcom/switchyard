defmodule Switchyard.TUI.App do
  @moduledoc false

  use ExRatatui.App, runtime: :reducer

  alias Switchyard.TUI.Root
  alias Workbench.Runtime

  @impl true
  def init(opts), do: Runtime.init(Root, opts)

  @impl true
  def render(state, frame), do: Runtime.render(state, frame)

  @impl true
  def update(msg, state), do: Runtime.update(msg, state)

  @impl true
  def subscriptions(state), do: Runtime.subscriptions(state)
end
