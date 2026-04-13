defmodule Switchyard.TUI.App do
  @moduledoc false

  use ExRatatui.App, runtime: :reducer

  alias Switchyard.TUI.Root
  alias Switchyard.TUI.Theme
  alias Workbench.Devtools.SessionArtifacts
  alias Workbench.Runtime

  @impl true
  def init(opts) do
    opts
    |> ensure_debug_runtime_opts()
    |> Keyword.put_new(:theme, Theme.default())
    |> then(&Runtime.init(Root, &1))
  end

  @impl true
  def render(state, frame), do: Runtime.render(state, frame)

  @impl true
  def update(msg, state), do: Runtime.update(msg, state)

  @impl true
  def subscriptions(state), do: Runtime.subscriptions(state)

  defp ensure_debug_runtime_opts(opts) do
    if Keyword.get(opts, :debug, false) and is_nil(Keyword.get(opts, :devtools)) do
      Keyword.put(
        opts,
        :devtools,
        SessionArtifacts.runtime_config(
          session_label: "switchyard_tui",
          base_dir: Keyword.get(opts, :debug_dir),
          history_limit: Keyword.get(opts, :debug_history_limit, 50)
        )
      )
    else
      opts
    end
  end
end
