defmodule Switchyard.TUI.Root do
  @moduledoc false

  @behaviour Workbench.Component

  alias Switchyard.Contracts.{Action, Resource}
  alias Switchyard.Platform
  alias Switchyard.Platform.Registry
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

  def update({:set_action_input, action_id, key, value}, %State{} = state, _props, _ctx)
      when is_binary(action_id) and is_binary(key) do
    action_input =
      state.action_form
      |> Map.get(action_id, %{})
      |> Map.put(key, value)

    next_state = %{state | action_form: Map.put(state.action_form, action_id, action_input)}
    {:ok, next_state, []}
  end

  def update(:select_prev_action, %State{shell: %{route: :app}} = state, _props, _ctx) do
    {:ok, move_action_cursor(state, -1), []}
  end

  def update(:select_next_action, %State{shell: %{route: :app}} = state, _props, _ctx) do
    {:ok, move_action_cursor(state, 1), []}
  end

  def update(
        :run_selected_action,
        %State{shell: %{route: :app}} = state,
        _props,
        %Context{} = ctx
      ) do
    case {selected_action(state), selected_resource_ref(state), ctx.request_handler} do
      {%Action{} = _action, %{} = _resource_ref, nil} ->
        {:ok, State.set_status(state, "No runtime request handler configured.", :warn), []}

      {%Action{confirmation: confirmation} = action, %{} = _resource_ref, _request_handler}
      when confirmation in [:if_destructive, :always] ->
        next_state =
          state
          |> Map.put(:confirming_action, action)
          |> State.set_status("Confirm action: #{action.title}.", :warn)

        {:ok, next_state, []}

      {%Action{} = action, %{} = resource_ref, _request_handler} ->
        {:ok, State.set_status(state, "Running action: #{action.title}.", :info),
         [run_action_command(state, action, resource_ref, false)]}

      _other ->
        {:ok, State.set_status(state, "No action selected.", :warn), []}
    end
  end

  def update(
        :confirm_action,
        %State{confirming_action: %Action{} = action} = state,
        _props,
        %Context{} = ctx
      ) do
    case {selected_resource_ref(state), ctx.request_handler} do
      {%{} = resource_ref, request_handler} when not is_nil(request_handler) ->
        next_state =
          state
          |> Map.put(:confirming_action, nil)
          |> State.set_status("Running action: #{action.title}.", :info)

        {:ok, next_state, [run_action_command(state, action, resource_ref, true)]}

      _other ->
        {:ok, State.set_status(state, "No runtime request handler configured.", :warn), []}
    end
  end

  def update(:confirm_action, %State{} = state, _props, _ctx) do
    {:ok, State.set_status(state, "No action awaiting confirmation.", :warn), []}
  end

  def update(:cancel_action, %State{} = state, _props, _ctx) do
    next_state =
      state
      |> Map.put(:confirming_action, nil)
      |> State.set_status("Action cancelled.", :info)

    {:ok, next_state, []}
  end

  def update(msg, %State{} = state, _props, %Context{} = ctx) do
    _ = ctx
    _ = msg
    _ = state
    :unhandled
  end

  @impl true
  def handle_info({:snapshot_loaded, snapshot}, %State{} = state, _props, _ctx)
      when is_map(snapshot) do
    {:ok, snapshot_loaded_state(state, snapshot), []}
  end

  def handle_info({:snapshot_refresh_failed, reason}, %State{} = state, _props, _ctx) do
    {:ok, State.set_status(state, "Snapshot refresh failed: #{inspect(reason)}", :error), []}
  end

  def handle_info({:process_started, {:ok, _result}}, %State{} = state, _props, _ctx) do
    {:ok, State.set_status(state, "Process started.", :info), [refresh_snapshot_command()]}
  end

  def handle_info({:process_started, {:error, reason}}, %State{} = state, _props, _ctx) do
    {:ok, State.set_status(state, "Process start failed: #{inspect(reason)}", :error), []}
  end

  def handle_info({:logs_loaded, stream_id, events}, %State{} = state, _props, _ctx)
      when is_binary(stream_id) and is_list(events) do
    next_state = put_in(state.log_previews[stream_id], events)
    {:ok, State.set_status(next_state, "Recent logs loaded.", :info), []}
  end

  def handle_info({:logs_load_failed, _stream_id, reason}, %State{} = state, _props, _ctx) do
    {:ok, State.set_status(state, "Log load failed: #{inspect(reason)}", :error), []}
  end

  def handle_info({:action_completed, result}, %State{} = state, _props, _ctx) do
    handle_action_completed(result, state)
  end

  def handle_info(_msg, %State{} = _state, _props, %Context{} = _ctx), do: :unhandled

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
          ] ++ maybe_local_process_bindings(state, ctx) ++ action_bindings(state)

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
                detail_lines(
                  State.detail_for_selected_resource(state),
                  action_lines(state),
                  log_preview_lines(state)
                )
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
      local_process_help_suffix(state, ctx) ++ action_help_suffix(state) ++ debug_help_suffix(ctx)
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

  defp snapshot_loaded_state(%State{} = state, snapshot) do
    next_state = %{state | snapshot: snapshot}

    case recovery_warning(snapshot) do
      nil -> State.set_status(next_state, "Snapshot refreshed.", :info)
      warning -> State.set_status(next_state, "Recovery warning: #{warning}", :warn)
    end
  end

  defp recovery_warning(%{recovery_status: %{status: status, warnings: [warning | _rest]}})
       when status in [:degraded, "degraded"] and is_binary(warning) do
    warning
  end

  defp recovery_warning(%{
         "recovery_status" => %{"status" => "degraded", "warnings" => [warning | _rest]}
       })
       when is_binary(warning) do
    warning
  end

  defp recovery_warning(_snapshot), do: nil

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

  defp detail_lines(nil, _action_lines, _log_preview_lines), do: ["No detail available."]

  defp detail_lines(
         %{sections: sections, recommended_actions: recommended_actions},
         action_lines,
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

    body ++ recommendations ++ action_lines ++ log_preview_lines
  end

  defp action_lines(%State{} = state) do
    actions = actions_for_selected_resource(state)

    if actions == [] do
      []
    else
      ["", "Available Actions"] ++
        action_line_items(actions, state) ++ selected_action_input_lines(state)
    end
  end

  defp action_line_items(actions, %State{} = state) do
    selected_index = selected_action_index(state, actions)

    actions
    |> Enum.with_index()
    |> Enum.map(fn {action, index} ->
      marker = if index == selected_index, do: ">", else: " "
      "  #{marker} #{action.title}"
    end)
  end

  defp selected_action_input_lines(%State{} = state) do
    case selected_action(state) do
      %Action{} = action ->
        action_input_lines(action_input(state, action))

      nil ->
        []
    end
  end

  defp action_input_lines(input) when input == %{}, do: []

  defp action_input_lines(input) do
    ["", "Action Input"] ++
      Enum.map(input, fn {key, value} -> "  #{key}: #{inspect(value)}" end)
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

  defp run_action_command(%State{} = state, %Action{} = action, resource_ref, confirmed?) do
    request =
      %{
        kind: :execute_action,
        action_id: action.id,
        resource: resource_ref,
        input: action_input(state, action)
      }
      |> maybe_confirm_action(confirmed?)

    Cmd.request(request, [], &{:action_completed, &1})
  end

  defp maybe_confirm_action(request, true), do: Map.put(request, :confirmed?, true)
  defp maybe_confirm_action(request, _confirmed?), do: request

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

  defp action_bindings(%State{} = state) do
    case actions_for_selected_resource(state) do
      [] ->
        []

      _actions ->
        [
          binding(:prev_action, "left", [], "Select previous action", :select_prev_action),
          binding(:next_action, "right", [], "Select next action", :select_next_action),
          binding(:run_selected_action, "a", [], "Run action", :run_selected_action),
          binding(:confirm_action, "y", [], "Confirm action", :confirm_action),
          binding(:cancel_action, "n", [], "Cancel action", :cancel_action)
        ]
    end
  end

  defp action_help_suffix(%State{} = state) do
    case actions_for_selected_resource(state) do
      [] -> []
      _actions -> ["Left/Right select action  ·  A run action  ·  Y/N confirm/cancel"]
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

  defp actions_for_selected_resource(%State{} = state) do
    case {State.current_app(state), State.selected_resource(state)} do
      {%{provider: provider}, %Resource{} = resource} when is_atom(provider) ->
        Registry.actions_for_resource(resource, [provider], state.snapshot)

      _other ->
        []
    end
  end

  defp selected_action(%State{} = state) do
    actions = actions_for_selected_resource(state)
    Enum.at(actions, selected_action_index(state, actions))
  end

  defp selected_action_index(%State{} = state, []), do: state.action_cursor

  defp selected_action_index(%State{} = state, actions) do
    state.action_cursor
    |> max(0)
    |> min(length(actions) - 1)
  end

  defp move_action_cursor(%State{} = state, delta) do
    actions = actions_for_selected_resource(state)
    moved_state = %{state | action_cursor: state.action_cursor + delta}
    %{state | action_cursor: selected_action_index(moved_state, actions)}
  end

  defp selected_resource_ref(%State{} = state) do
    case State.selected_resource(state) do
      %Resource{} = resource -> %{site_id: resource.site_id, kind: resource.kind, id: resource.id}
      _other -> nil
    end
  end

  defp action_input(%State{} = state, %Action{} = action) do
    action
    |> default_action_input()
    |> Map.merge(Map.get(state.action_form, action.id, %{}))
  end

  defp default_action_input(%Action{input_schema: schema}) do
    schema
    |> Map.get("properties", Map.get(schema, :properties, %{}))
    |> Enum.reduce(%{}, fn {key, field_schema}, acc ->
      case default_value(field_schema) do
        {:ok, value} -> Map.put(acc, to_string(key), value)
        :error -> acc
      end
    end)
  end

  defp default_value(%{"default" => value}), do: {:ok, value}
  defp default_value(%{default: value}), do: {:ok, value}
  defp default_value(_schema), do: :error

  defp handle_action_completed({:ok, result}, %State{} = state) do
    next_state =
      state
      |> Map.put(:last_action_result, {:ok, result})
      |> State.set_status("Action completed: #{action_result_message(result)}", :info)

    {:ok, next_state, []}
  end

  defp handle_action_completed({:error, reason}, %State{} = state) do
    next_state =
      state
      |> Map.put(:last_action_result, {:error, reason})
      |> State.set_status("Action failed: #{inspect(reason)}", :error)

    {:ok, next_state, []}
  end

  defp handle_action_completed(other, %State{} = state) do
    next_state =
      state
      |> Map.put(:last_action_result, other)
      |> State.set_status("Action returned: #{inspect(other)}", :info)

    {:ok, next_state, []}
  end

  defp action_result_message(%{message: message}) when is_binary(message), do: message
  defp action_result_message(%{"message" => message}) when is_binary(message), do: message
  defp action_result_message(result), do: inspect(result)
end
