defmodule Switchyard.TUI.Controller do
  @moduledoc false

  alias ExRatatui.Event
  alias Switchyard.Shell
  alias Switchyard.TUI.{Keymap, Model}

  @spec event_to_msg(Event.t(), Model.t()) :: :ignore | {:msg, term()}
  def event_to_msg(%Event.Resize{width: width, height: height}, _state),
    do: {:msg, {:resize, width, height}}

  def event_to_msg(%Event.Key{} = event, %Model{} = state), do: Keymap.to_msg(event, state)

  @spec update(term(), Model.t()) :: {Model.t(), [term()]} | {:stop, Model.t()}
  def update(:quit, state), do: {:stop, state}

  def update(:select_prev, %Model{shell: %{route: :home}} = state),
    do: {Model.move_home_cursor(state, -1), []}

  def update(:select_prev, %Model{shell: %{route: :site_apps}} = state),
    do: {Model.move_site_app_cursor(state, -1), []}

  def update(:select_prev, %Model{shell: %{route: :app}} = state),
    do: {Model.move_resource_cursor(state, -1), []}

  def update(:select_prev, state), do: {state, []}

  def update(:select_next, %Model{shell: %{route: :home}} = state),
    do: {Model.move_home_cursor(state, 1), []}

  def update(:select_next, %Model{shell: %{route: :site_apps}} = state),
    do: {Model.move_site_app_cursor(state, 1), []}

  def update(:select_next, %Model{shell: %{route: :app}} = state),
    do: {Model.move_resource_cursor(state, 1), []}

  def update(:select_next, state), do: {state, []}

  def update(:enter, %Model{shell: %{route: :home}} = state) do
    case Model.selected_home_site(state) do
      %{id: site_id} ->
        next_state =
          state
          |> Model.select_site(site_id)
          |> then(fn next_state ->
            %{next_state | shell: Shell.reduce(next_state.shell, {:open_route, :site_apps})}
          end)
          |> Model.set_status("Opened site apps.", :info)

        {next_state, []}

      nil ->
        {Model.set_status(state, "No site selected.", :warn), []}
    end
  end

  def update(:enter, %Model{shell: %{route: :site_apps}} = state) do
    case Model.selected_site_app(state) do
      nil -> {Model.set_status(state, "No app selected.", :warn), []}
      app -> open_app_descriptor(state, app)
    end
  end

  def update(:enter, state), do: {state, []}

  def update(:back, %Model{shell: %{route: :app}} = state) do
    {%{state | shell: Shell.reduce(state.shell, {:open_route, :site_apps})}
     |> Model.set_status("Returned to app list.", :info), []}
  end

  def update(:back, %Model{shell: %{route: :site_apps}} = state) do
    {%{state | shell: Shell.reduce(state.shell, {:open_route, :home})}, []}
  end

  def update(:back, state), do: {state, []}

  def update({:resize, width, height}, state) do
    {%{state | screen_width: width, screen_height: height}, []}
  end

  def update(msg, %Model{} = state) do
    case {state.shell.route, Model.current_mount_module(state)} do
      {:app, module} when is_atom(module) ->
        case module.update(msg, state, Model.current_mount_state(state)) do
          {next_state, mount_state, commands} ->
            {Model.put_mount_state(next_state, state.shell.selected_app_id, mount_state),
             commands}

          :unhandled ->
            {state, []}
        end

      _other ->
        {state, []}
    end
  end

  @spec open_app(Model.t(), String.t()) :: {Model.t(), [term()]}
  def open_app(%Model{} = state, app_id) when is_binary(app_id) do
    case Enum.find(state.apps, &(&1.id == app_id)) do
      nil -> {Model.set_status(state, "Unknown app: #{app_id}", :error), []}
      app -> open_app_descriptor(state, app)
    end
  end

  defp open_app_descriptor(state, app) do
    site_apps = Enum.filter(state.apps, &(&1.site_id == app.site_id))
    site_app_cursor = Enum.find_index(site_apps, &(&1.id == app.id)) || 0

    next_state =
      state
      |> Model.select_site(app.site_id)
      |> Model.select_app(app.id)
      |> Map.put(:site_app_cursor, site_app_cursor)
      |> then(fn next_state ->
        %{next_state | shell: Shell.reduce(next_state.shell, {:open_route, :app})}
      end)

    case Model.current_mount_module(next_state) do
      nil ->
        {Model.set_status(next_state, "Opened #{app.title}.", :info), []}

      module ->
        {mounted_state, mount_state, commands} =
          module.open(next_state, Model.current_mount_state(next_state))

        {Model.put_mount_state(mounted_state, app.id, mount_state), commands}
    end
  end
end
