defmodule Switchyard.Shell do
  @moduledoc """
  Pure shell state and reducer helpers for the terminal host.
  """

  defmodule State do
    @moduledoc "Serializable shell state."

    @type t :: %__MODULE__{
            route: atom(),
            selected_site_id: String.t() | nil,
            focused_pane: atom(),
            drawers: %{jobs: boolean(), logs: boolean()},
            notifications: [String.t()]
          }

    defstruct route: :home,
              selected_site_id: nil,
              focused_pane: :main,
              drawers: %{jobs: false, logs: false},
              notifications: []
  end

  @type event ::
          {:open_route, atom()}
          | {:select_site, String.t()}
          | {:focus_pane, atom()}
          | {:toggle_drawer, :jobs | :logs}
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

  def reduce(%State{} = state, {:focus_pane, pane}) when is_atom(pane) do
    %{state | focused_pane: pane}
  end

  def reduce(%State{} = state, {:toggle_drawer, drawer}) when drawer in [:jobs, :logs] do
    %{state | drawers: Map.update!(state.drawers, drawer, &(!&1))}
  end

  def reduce(%State{} = state, {:notify, message}) when is_binary(message) do
    %{state | notifications: Enum.take([message | state.notifications], 20)}
  end
end
