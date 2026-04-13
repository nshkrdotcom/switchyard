defmodule Switchyard.ShellTest do
  use ExUnit.Case, async: true

  alias Switchyard.Shell

  test "tracks route, site selection, and pane focus" do
    state =
      Shell.new()
      |> Shell.reduce({:open_route, :sites})
      |> Shell.reduce({:select_site, "example"})
      |> Shell.reduce({:select_app, "example.rooms"})
      |> Shell.reduce({:focus_pane, :detail})

    assert state.route == :sites
    assert state.selected_site_id == "example"
    assert state.selected_app_id == "example.rooms"
    assert state.focused_pane == :detail
  end

  test "toggles drawers and retains latest notifications" do
    state =
      Shell.new()
      |> Shell.reduce({:toggle_drawer, :jobs})
      |> Shell.reduce({:toggle_drawer, :logs})
      |> Shell.reduce({:open_overlay, :help})
      |> Shell.reduce({:notify, "daemon connected"})

    assert state.drawers.jobs
    assert state.drawers.logs
    assert state.overlay == :help
    assert state.notifications == ["daemon connected"]

    assert Shell.reduce(state, :close_overlay).overlay == nil
  end
end
