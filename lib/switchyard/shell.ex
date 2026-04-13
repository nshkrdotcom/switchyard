defmodule Switchyard.Shell do
  @moduledoc """
  Pure shell state and reducer helpers for the terminal host.
  """

  defmodule State do
    @moduledoc "Serializable shell state."

    @type t :: %__MODULE__{
            route: atom(),
            selected_site_id: String.t() | nil,
            selected_app_id: String.t() | nil,
            focused_pane: atom(),
            drawers: %{jobs: boolean(), logs: boolean()},
            overlay: atom() | nil,
            notifications: [String.t()]
          }

    defstruct route: :home,
              selected_site_id: nil,
              selected_app_id: nil,
              focused_pane: :main,
              drawers: %{jobs: false, logs: false},
              overlay: nil,
              notifications: []
  end

  @type event ::
          {:open_route, atom()}
          | {:select_site, String.t()}
          | {:select_app, String.t()}
          | {:focus_pane, atom()}
          | {:toggle_drawer, :jobs | :logs}
          | {:open_overlay, atom()}
          | :close_overlay
          | {:notify, String.t()}

  @spec new() :: State.t()
  def new, do: %State{}

  @spec reduce(State.t(), event()) :: State.t()
  def reduce(%State{} = state, {:open_route, route}) when is_atom(route) do
    %{state | route: route}
  end

  def reduce(%State{} = state, {:select_site, site_id}) when is_binary(site_id) do
    %{state | selected_site_id: site_id}
  end

  def reduce(%State{} = state, {:select_app, app_id}) when is_binary(app_id) do
    %{state | selected_app_id: app_id}
  end

  def reduce(%State{} = state, {:focus_pane, pane}) when is_atom(pane) do
    %{state | focused_pane: pane}
  end

  def reduce(%State{} = state, {:toggle_drawer, drawer}) when drawer in [:jobs, :logs] do
    %{state | drawers: Map.update!(state.drawers, drawer, &(!&1))}
  end

  def reduce(%State{} = state, {:open_overlay, overlay}) when is_atom(overlay) do
    %{state | overlay: overlay}
  end

  def reduce(%State{} = state, :close_overlay) do
    %{state | overlay: nil}
  end

  def reduce(%State{} = state, {:notify, message}) when is_binary(message) do
    %{state | notifications: Enum.take([message | state.notifications], 20)}
  end
end
