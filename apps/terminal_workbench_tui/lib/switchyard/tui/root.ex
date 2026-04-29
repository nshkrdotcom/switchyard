defmodule Switchyard.TUI.Root do
  @moduledoc false

  @behaviour Workbench.Component

  alias Switchyard.Platform
  alias Switchyard.Shell
  alias Switchyard.Site.ExecutionPlane
  alias Switchyard.TUI.State
  alias Workbench.{Cmd, Context, Keymap, Layout, Node, Style}
  alias Workbench.Devtools.Overlay
  alias Workbench.Widgets.{Detail, Help, List, Pane, StatusBar}

  @impl true
  def init(props, %Context{} = ctx) do
    catalog = Platform.catalog(Map.get(props, :site_modules, [ExecutionPlane]))

    state =
      State.new(
        sites: catalog.sites,
        apps: catalog.apps,
        debug_overlay_visible: Map.get(props, :debug, false),
        snapshot: Map.get(props, :snapshot, %{processes: [], jobs: []}),
        context: props,
        app_component_overrides:
          normalize_component_overrides(Map.get(props, :app_component_modules, %{}))
      )

    case Map.get(props, :open_app) do
      app_id when is_binary(app_id) and app_id != "" ->
        open_app(state, app_id, ctx)

      _other ->
        {:ok, state, startup_commands(ctx)}
    end
  end

  @impl true
  def update(:quit, %State{} = state, _props, _ctx), do: {:stop, state}

  def update(:select_prev, %State{shell: %{route: :home}} = state, _props, _ctx),
    do: {:ok, State.move_home_cursor(state, -1), []}

  def update(:select_prev, %State{shell: %{route: :site_apps}} = state, _props, _ctx),
    do: {:ok, State.move_site_app_cursor(state, -1), []}

  def update(:select_prev, %State{shell: %{route: :app}} = state, _props, _ctx) do
    if is_nil(State.current_app_component_module(state)) do
      {:ok, State.move_resource_cursor(state, -1), []}
    else
      :unhandled
    end
  end

  def update(:select_next, %State{shell: %{route: :home}} = state, _props, _ctx),
    do: {:ok, State.move_home_cursor(state, 1), []}

  def update(:select_next, %State{shell: %{route: :site_apps}} = state, _props, _ctx),
    do: {:ok, State.move_site_app_cursor(state, 1), []}

  def update(:select_next, %State{shell: %{route: :app}} = state, _props, _ctx) do
    if is_nil(State.current_app_component_module(state)) do
      {:ok, State.move_resource_cursor(state, 1), []}
    else
      :unhandled
    end
  end

  def update(:enter, %State{shell: %{route: :home}} = state, _props, _ctx) do
    case State.selected_home_site(state) do
      %{id: site_id} ->
        next_state =
          state
          |> State.select_site(site_id)
          |> then(fn next_state ->
            %{next_state | shell: Shell.reduce(next_state.shell, {:open_route, :site_apps})}
          end)
          |> State.set_status("Opened site apps.", :info)

        {:ok, next_state, []}

      nil ->
        {:ok, State.set_status(state, "No site selected.", :warn), []}
    end
  end

  def update(:enter, %State{shell: %{route: :site_apps}} = state, _props, %Context{} = ctx) do
    case State.selected_site_app(state) do
      nil -> {:ok, State.set_status(state, "No app selected.", :warn), []}
      app -> open_app(state, app.id, ctx)
    end
  end

  def update(:back, %State{shell: %{route: :app}} = state, _props, _ctx) do
    next_state =
      state
      |> Map.put(:shell, Shell.reduce(state.shell, {:open_route, :site_apps}))
      |> State.set_status("Returned to app list.", :info)

    {:ok, next_state, []}
  end

  def update(:back, %State{shell: %{route: :site_apps}} = state, _props, _ctx) do
    {:ok, %{state | shell: Shell.reduce(state.shell, {:open_route, :home})}, []}
  end

  def update(:toggle_debug_overlay, %State{} = state, _props, %Context{} = ctx) do
    if debug_enabled?(ctx) do
      next_state = %{state | debug_overlay_visible: not state.debug_overlay_visible}
      {:ok, State.set_status(next_state, debug_overlay_status(next_state), :info), []}
    else
      :unhandled
    end
  end

  def update(:refresh_snapshot, %State{} = state, _props, %Context{} = ctx) do
    if is_nil(ctx.request_handler) do
      {:ok, State.set_status(state, "No runtime request handler configured.", :warn), []}
    else
      {:ok, State.set_status(state, "Refreshing snapshot...", :info),
       [refresh_snapshot_command()]}
    end
  end

  def update(:start_demo_process, %State{} = state, _props, %Context{} = ctx) do
    if execution_plane_processes_app?(state) and not is_nil(ctx.request_handler) do
      {:ok, State.set_status(state, "Starting demo process...", :info),
       [start_demo_process_command()]}
    else
      :unhandled
    end
  end

  def update(:load_selected_logs, %State{} = state, _props, %Context{} = ctx) do
    case {selected_process_stream_id(state), ctx.request_handler} do
      {stream_id, request_handler} when is_binary(stream_id) and not is_nil(request_handler) ->
        {:ok, State.set_status(state, "Loading recent logs...", :info),
         [load_logs_command(stream_id)]}

      _other ->
        :unhandled
    end
  end

  def update(msg, %State{} = state, _props, %Context{} = ctx) do
    _ = ctx
    _ = msg
    _ = state
    :unhandled
  end

  @impl true
  def handle_info(msg, %State{} = state, _props, %Context{} = ctx) do
    case msg do
      {:snapshot_loaded, snapshot} when is_map(snapshot) ->
        {:ok, %{state | snapshot: snapshot} |> State.set_status("Snapshot refreshed.", :info), []}

      {:snapshot_refresh_failed, reason} ->
        {:ok, State.set_status(state, "Snapshot refresh failed: #{inspect(reason)}", :error), []}

      {:process_started, {:ok, _result}} ->
        {:ok, State.set_status(state, "Process started.", :info), [refresh_snapshot_command()]}

      {:process_started, {:error, reason}} ->
        {:ok, State.set_status(state, "Process start failed: #{inspect(reason)}", :error), []}

      {:logs_loaded, stream_id, events} when is_binary(stream_id) and is_list(events) ->
        next_state = put_in(state.log_previews[stream_id], events)
        {:ok, State.set_status(next_state, "Recent logs loaded.", :info), []}

      {:logs_load_failed, _stream_id, reason} ->
        {:ok, State.set_status(state, "Log load failed: #{inspect(reason)}", :error), []}

      _other ->
        _ = ctx
        :unhandled
    end
  end

  @impl true
  def render(%State{shell: %{route: :home}} = state, _props, %Context{} = ctx) do
    content =
      Node.vstack(
        :root,
        [
          Pane.new(
            id: :header,
            title: "Switchyard",
            lines: ["Terminal workbench for execution-plane and Jido operator surfaces"]
          )
          |> Style.border_fg(:accent),
          List.new(
            id: :sites,
            title: "Sites",
            items: Enum.map(state.sites, & &1.title),
            selected: state.home_cursor,
            meta: [focusable: true, region: Workbench.Mouse.region(:sites)]
          )
          |> Style.border_fg(:warning)
          |> Style.highlight_fg(:focus),
          Help.new(
            id: :help,
            title: "Keys",
            lines: home_help_lines(ctx)
          )
          |> Style.border_fg(:muted),
          status_node(state)
        ],
        constraints: [{:length, 3}, {:min, 8}, {:length, 3}, {:length, 1}]
      )

    content
    |> Layout.with_padding({1, 1, 0, 0})
    |> maybe_wrap_debug(state, ctx)
  end

  def render(%State{shell: %{route: :site_apps}} = state, _props, %Context{} = ctx) do
    selected_site =
      State.selected_home_site(state) || %{title: state.shell.selected_site_id || "Site"}

    content =
      Node.vstack(
        :root,
        [
          Pane.new(
            id: :header,
            title: selected_site.title,
            lines: ["Installed apps"]
          )
          |> Style.border_fg(:accent),
          List.new(
            id: :apps,
            title: "Apps",
            items: Enum.map(State.apps_for_selected_site(state), & &1.title),
            selected: state.site_app_cursor,
            meta: [focusable: true, region: Workbench.Mouse.region(:apps)]
          )
          |> Style.border_fg(:warning)
          |> Style.highlight_fg(:focus),
          Help.new(
            id: :help,
            title: "Keys",
            lines: site_apps_help_lines(ctx)
          )
          |> Style.border_fg(:muted),
          status_node(state)
        ],
        constraints: [{:length, 3}, {:min, 8}, {:length, 3}, {:length, 1}]
      )

    content
    |> Layout.with_padding({1, 1, 0, 0})
    |> maybe_wrap_debug(state, ctx)
  end

  def render(%State{shell: %{route: :app}} = state, _props, %Context{} = ctx) do
    content =
      case State.current_app_component_module(state) do
        nil ->
          generic_app_node(state, ctx)

        module ->
          Node.component(
            :active_app,
            module,
            child_props(state),
            mode: Workbench.Component.mode(module)
          )
      end

    maybe_wrap_debug(content, state, ctx)
  end

  @impl true
  def render_accessible(_state, _props, _ctx), do: :unsupported

  @impl true
  def keymap(%State{shell: %{route: :home}}, _props, ctx) do
    [
      binding(:quit, "q", ["ctrl"], "Quit", :quit),
      binding(:prev, "up", [], "Select previous", :select_prev),
      binding(:next, "down", [], "Select next", :select_next),
      binding(:enter, "enter", [], "Open site", :enter)
    ]
    |> maybe_add_debug_binding(ctx)
  end

  def keymap(%State{shell: %{route: :site_apps}}, _props, ctx) do
    [
      binding(:quit, "q", ["ctrl"], "Quit", :quit),
      binding(:prev, "up", [], "Select previous", :select_prev),
      binding(:next, "down", [], "Select next", :select_next),
      binding(:enter, "enter", [], "Open app", :enter),
      binding(:back, "esc", [], "Back", :back)
    ]
    |> maybe_add_debug_binding(ctx)
  end

  def keymap(%State{shell: %{route: :app}} = state, _props, %Context{} = ctx) do
    base =
      [
        binding(:quit, "q", ["ctrl"], "Quit", :quit),
        binding(:back, "esc", [], "Back", :back)
      ]
      |> maybe_add_debug_binding(ctx)

    case State.current_app_component_module(state) do
      nil ->
        base ++
          [
            binding(:prev, "up", [], "Select previous", :select_prev),
            binding(:next, "down", [], "Select next", :select_next),
            binding(:refresh_snapshot, "r", [], "Refresh snapshot", :refresh_snapshot),
            binding(:back, "esc", [], "Back", :back)
          ] ++ maybe_local_process_bindings(state, ctx)

      _module ->
        _ = ctx
        base
    end
  end

  @impl true
  def actions(_state, _props, _ctx), do: []

  @impl true
  def subscriptions(_state, _props, _ctx), do: []

  defp open_app(%State{} = state, app_id, %Context{} = ctx) when is_binary(app_id) do
    case Enum.find(state.apps, &(&1.id == app_id)) do
      nil ->
        {:ok, State.set_status(state, "Unknown app: #{app_id}", :error), []}

      app ->
        site_apps = Enum.filter(state.apps, &(&1.site_id == app.site_id))
        site_app_cursor = Enum.find_index(site_apps, &(&1.id == app.id)) || 0

        next_state =
          state
          |> State.select_site(app.site_id)
          |> State.select_app(app.id)
          |> Map.put(:site_app_cursor, site_app_cursor)
          |> then(fn next_state ->
            %{next_state | shell: Shell.reduce(next_state.shell, {:open_route, :app})}
          end)

        _ = ctx
        {:ok, State.set_status(next_state, "Opened #{app.id}.", :info), []}
    end
  end

  defp generic_app_node(%State{} = state, %Context{} = ctx) do
    app = State.current_app(state)

    Node.vstack(
      :root,
      [
        Pane.new(
          id: :header,
          title: app_title(app),
          lines: [app_subtitle(app)]
        )
        |> Style.border_fg(:accent),
        Node.hstack(
          :content,
          [
            List.new(
              id: :resources,
              title: "Resources",
              items: resource_lines(state),
              selected: state.resource_cursor,
              meta: [focusable: true, region: Workbench.Mouse.region(:resources)]
            )
            |> Style.border_fg(:warning)
            |> Style.highlight_fg(:focus),
            Detail.new(
              id: :detail,
              title: "Detail",
              lines:
                detail_lines(State.detail_for_selected_resource(state), log_preview_lines(state))
            )
            |> Style.border_fg(:success)
          ],
          constraints: [{:percentage, 42}, {:percentage, 58}]
        ),
        Help.new(
          id: :help,
          title: "Keys",
          lines: generic_app_help_lines(state, ctx)
        )
        |> Style.border_fg(:muted),
        status_node(state)
      ],
      constraints: [{:length, 3}, {:min, 8}, {:length, 3}, {:length, 1}]
    )
    |> Layout.with_padding({1, 1, 0, 0})
  end

  defp child_props(%State{} = state) do
    %{
      app: State.current_app(state),
      context: state.context,
      snapshot: state.snapshot
    }
  end

  defp normalize_component_overrides(overrides) when is_map(overrides), do: overrides
  defp normalize_component_overrides(overrides) when is_list(overrides), do: Map.new(overrides)
  defp normalize_component_overrides(_other), do: %{}

  defp binding(id, code, modifiers, description, message) do
    Keymap.binding(
      id: id,
      keys: [Keymap.key(code, modifiers)],
      description: description,
      message: message
    )
  end

  defp maybe_wrap_debug(%Node{} = content, %State{debug_overlay_visible: true}, %Context{} = ctx) do
    if debug_enabled?(ctx) do
      Node.hstack(
        :debug_shell,
        [
          content,
          Overlay.node(ctx.devtools)
        ],
        constraints: [{:percentage, 70}, {:percentage, 30}]
      )
    else
      content
    end
  end

  defp maybe_wrap_debug(%Node{} = content, _state, _ctx), do: content

  defp maybe_add_debug_binding(bindings, %Context{} = ctx) do
    if debug_enabled?(ctx) do
      bindings ++
        [binding(:toggle_debug_overlay, "f12", [], "Toggle debug rail", :toggle_debug_overlay)]
    else
      bindings
    end
  end

  defp debug_enabled?(%Context{} = ctx), do: Map.get(ctx.devtools, :enabled?, false)

  defp debug_overlay_status(%State{debug_overlay_visible: true}), do: "Debug rail shown."
  defp debug_overlay_status(%State{debug_overlay_visible: false}), do: "Debug rail hidden."

  defp home_help_lines(%Context{} = ctx) do
    ["Up/Down select site  ·  Enter open  ·  Ctrl+Q quit"] ++ debug_help_suffix(ctx)
  end

  defp site_apps_help_lines(%Context{} = ctx) do
    ["Up/Down select app  ·  Enter open  ·  Esc home  ·  Ctrl+Q quit"] ++ debug_help_suffix(ctx)
  end

  defp generic_app_help_lines(%State{} = state, %Context{} = ctx) do
    ["Up/Down select resource  ·  R refresh  ·  Esc back  ·  Ctrl+Q quit"] ++
      local_process_help_suffix(state, ctx) ++ debug_help_suffix(ctx)
  end

  defp debug_help_suffix(%Context{} = ctx) do
    if debug_enabled?(ctx) do
      ["F12 toggle debug rail"]
    else
      []
    end
  end

  defp local_process_help_suffix(%State{} = state, %Context{} = ctx) do
    if execution_plane_processes_app?(state) do
      ["N start demo process" | selected_process_log_help(state, ctx)]
    else
      []
    end
  end

  defp status_node(%State{} = state) do
    StatusBar.new(
      id: :status,
      text: state.status_line
    )
    |> Style.fg(status_tone(state.status_severity))
  end

  defp status_tone(:error), do: :danger
  defp status_tone(:warn), do: :warning
  defp status_tone(_severity), do: :success

  defp app_title(nil), do: "App"
  defp app_title(app), do: app.title

  defp app_subtitle(nil), do: "No app selected"
  defp app_subtitle(app), do: "Route kind: #{app.route_kind}"

  defp resource_lines(%State{} = state) do
    state
    |> State.resources_for_selected_app()
    |> Enum.map(fn resource -> "#{resource.title}#{resource_subtitle(resource)}" end)
  end

  defp resource_subtitle(%{subtitle: nil}), do: ""
  defp resource_subtitle(%{subtitle: subtitle}), do: "  ·  #{subtitle}"

  defp detail_lines(nil, _log_preview_lines), do: ["No detail available."]

  defp detail_lines(
         %{sections: sections, recommended_actions: recommended_actions},
         log_preview_lines
       ) do
    body =
      sections
      |> Enum.flat_map(fn section ->
        [section.title] ++ Enum.map(section.lines, &"  #{&1}")
      end)

    recommendations =
      if recommended_actions == [] do
        []
      else
        ["", "Recommended Actions"] ++ Enum.map(recommended_actions, &"  #{&1}")
      end

    body ++ recommendations ++ log_preview_lines
  end

  defp log_preview_lines(%State{} = state) do
    with stream_id when is_binary(stream_id) <- selected_process_stream_id(state),
         events when events != [] <- Map.get(state.log_previews, stream_id, []) do
      ["", "Recent Logs"] ++ Enum.map(events, &log_event_line/1)
    else
      _other -> []
    end
  end

  defp log_event_line(%{fields: fields, level: level, message: message}) do
    seq = Map.get(fields, :seq) || Map.get(fields, "seq")
    seq_prefix = if is_nil(seq), do: "", else: "##{seq} "
    "  #{seq_prefix}#{level}: #{message}"
  end

  defp log_event_line(%{message: message}), do: "  #{message}"

  defp startup_commands(%Context{} = ctx) do
    if is_nil(ctx.request_handler), do: [], else: [refresh_snapshot_command()]
  end

  defp refresh_snapshot_command do
    Cmd.request(:local_snapshot, [], fn
      snapshot when is_map(snapshot) -> {:snapshot_loaded, snapshot}
      other -> {:snapshot_refresh_failed, other}
    end)
  end

  defp start_demo_process_command do
    Cmd.request(
      {:start_process,
       %{
         label: "Switchyard Demo",
         command: "printf 'switchyard demo process\\n'"
       }},
      [],
      &{:process_started, &1}
    )
  end

  defp load_logs_command(stream_id) do
    Cmd.request({:logs, stream_id, [tail: 5]}, [], fn
      events when is_list(events) -> {:logs_loaded, stream_id, events}
      other -> {:logs_load_failed, stream_id, other}
    end)
  end

  defp execution_plane_processes_app?(%State{} = state) do
    case State.current_app(state) do
      %{id: "execution_plane.processes"} -> true
      _other -> false
    end
  end

  defp maybe_local_process_bindings(%State{} = state, %Context{} = ctx) do
    if execution_plane_processes_app?(state) do
      [binding(:start_demo_process, "n", [], "Start demo process", :start_demo_process)] ++
        selected_process_log_binding(state, ctx)
    else
      []
    end
  end

  defp selected_process_log_binding(%State{} = state, %Context{} = ctx) do
    case {selected_process_stream_id(state), ctx.request_handler} do
      {stream_id, request_handler} when is_binary(stream_id) and not is_nil(request_handler) ->
        [binding(:load_selected_logs, "l", [], "Load logs", :load_selected_logs)]

      _other ->
        []
    end
  end

  defp selected_process_log_help(%State{} = state, %Context{} = ctx) do
    case selected_process_log_binding(state, ctx) do
      [] -> []
      _bindings -> ["L load logs"]
    end
  end

  defp selected_process_stream_id(%State{} = state) do
    case State.selected_resource(state) do
      %{kind: :process, id: process_id} when is_binary(process_id) -> "logs/#{process_id}"
      _other -> nil
    end
  end
end
