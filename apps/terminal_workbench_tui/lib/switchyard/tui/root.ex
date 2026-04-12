defmodule Switchyard.TUI.Root do
  @moduledoc false

  @behaviour Workbench.Component

  alias ExRatatui.Style
  alias Switchyard.Platform
  alias Switchyard.Shell
  alias Switchyard.Site.Local
  alias Switchyard.TUI.State
  alias Workbench.{Context, Keymap, Node}
  alias Workbench.Widgets.{Detail, Help, List, Pane, StatusBar}

  @impl true
  def init(props, %Context{} = ctx) do
    catalog = Platform.catalog(Map.get(props, :site_modules, [Local]))

    state =
      State.new(
        sites: catalog.sites,
        apps: catalog.apps,
        snapshot: Map.get(props, :snapshot, %{processes: [], jobs: []}),
        context: props,
        app_component_overrides:
          normalize_component_overrides(Map.get(props, :app_component_modules, %{}))
      )

    case Map.get(props, :open_app) do
      app_id when is_binary(app_id) and app_id != "" ->
        open_app(state, app_id, ctx)

      _other ->
        {:ok, state, []}
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

  def update(msg, %State{} = state, _props, %Context{} = ctx) do
    delegate_to_component(msg, state, ctx)
  end

  @impl true
  def handle_info(msg, %State{} = state, _props, %Context{} = ctx) do
    delegate_info(msg, state, ctx)
  end

  @impl true
  def render(%State{shell: %{route: :home}} = state, _props, _ctx) do
    Node.vstack(
      :root,
      [
        Pane.new(
          id: :header,
          title: "Switchyard",
          lines: ["Terminal workbench for sites, jobs, logs, and processes"],
          border_fg: :cyan
        ),
        List.new(
          id: :sites,
          title: "Sites",
          items: Enum.map(state.sites, & &1.title),
          selected: state.home_cursor,
          border_fg: :yellow,
          meta: [focusable: true, region: Workbench.Mouse.region(:sites)]
        ),
        Help.new(
          id: :help,
          title: "Keys",
          lines: ["Up/Down select site  ·  Enter open  ·  Ctrl+Q quit"],
          border_fg: :dark_gray
        ),
        status_node(state)
      ],
      constraints: [{:length, 3}, {:min, 8}, {:length, 3}, {:length, 1}]
    )
  end

  def render(%State{shell: %{route: :site_apps}} = state, _props, _ctx) do
    selected_site =
      State.selected_home_site(state) || %{title: state.shell.selected_site_id || "Site"}

    Node.vstack(
      :root,
      [
        Pane.new(
          id: :header,
          title: selected_site.title,
          lines: ["Installed apps"],
          border_fg: :cyan
        ),
        List.new(
          id: :apps,
          title: "Apps",
          items: Enum.map(State.apps_for_selected_site(state), & &1.title),
          selected: state.site_app_cursor,
          border_fg: :yellow,
          meta: [focusable: true, region: Workbench.Mouse.region(:apps)]
        ),
        Help.new(
          id: :help,
          title: "Keys",
          lines: ["Up/Down select app  ·  Enter open  ·  Esc home  ·  Ctrl+Q quit"],
          border_fg: :dark_gray
        ),
        status_node(state)
      ],
      constraints: [{:length, 3}, {:min, 8}, {:length, 3}, {:length, 1}]
    )
  end

  def render(%State{shell: %{route: :app}} = state, _props, %Context{} = ctx) do
    case State.current_app_component_module(state) do
      nil ->
        generic_app_node(state)

      module ->
        child_ctx = child_context(ctx, state)
        child_props = child_props(state)
        child_state = State.current_app_component_state(state)
        module.render(child_state, child_props, child_ctx)
    end
  end

  @impl true
  def render_accessible(_state, _props, _ctx), do: :unsupported

  @impl true
  def keymap(%State{shell: %{route: :home}}, _props, _ctx) do
    [
      binding(:quit, "q", ["ctrl"], "Quit", :quit),
      binding(:prev, "up", [], "Select previous", :select_prev),
      binding(:next, "down", [], "Select next", :select_next),
      binding(:enter, "enter", [], "Open site", :enter)
    ]
  end

  def keymap(%State{shell: %{route: :site_apps}}, _props, _ctx) do
    [
      binding(:quit, "q", ["ctrl"], "Quit", :quit),
      binding(:prev, "up", [], "Select previous", :select_prev),
      binding(:next, "down", [], "Select next", :select_next),
      binding(:enter, "enter", [], "Open app", :enter),
      binding(:back, "esc", [], "Back", :back)
    ]
  end

  def keymap(%State{shell: %{route: :app}} = state, _props, %Context{} = ctx) do
    base = [binding(:quit, "q", ["ctrl"], "Quit", :quit)]

    case State.current_app_component_module(state) do
      nil ->
        base ++
          [
            binding(:prev, "up", [], "Select previous", :select_prev),
            binding(:next, "down", [], "Select next", :select_next),
            binding(:back, "esc", [], "Back", :back)
          ]

      module ->
        child_ctx = child_context(ctx, state)
        child_props = child_props(state)
        child_state = State.current_app_component_state(state)

        base ++
          if(function_exported?(module, :keymap, 3),
            do: module.keymap(child_state, child_props, child_ctx),
            else: []
          )
    end
  end

  @impl true
  def actions(_state, _props, _ctx), do: []

  @impl true
  def subscriptions(%State{} = state, _props, %Context{} = ctx) do
    case State.current_app_component_module(state) do
      nil ->
        []

      module ->
        child_ctx = child_context(ctx, state)
        child_props = child_props(state)
        child_state = State.current_app_component_state(state)

        if function_exported?(module, :subscriptions, 3) do
          module.subscriptions(child_state, child_props, child_ctx)
        else
          []
        end
    end
  end

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

        maybe_init_component(next_state, ctx, app)
    end
  end

  defp maybe_init_component(%State{} = state, %Context{} = ctx, %{id: app_id}) do
    case State.current_app_component_module(state) do
      nil ->
        {:ok, State.set_status(state, "Opened #{app_id}.", :info), []}

      module ->
        if Code.ensure_loaded?(module) do
          child_ctx = child_context(ctx, state)
          child_props = child_props(state)
          {:ok, child_state, cmds} = module.init(child_props, child_ctx)

          next_state =
            state
            |> State.put_app_component_state(app_id, child_state)
            |> State.set_status("Opened #{app_id}.", :info)

          {:ok, next_state, cmds}
        else
          {:ok,
           State.set_status(state, "TUI component #{inspect(module)} is unavailable.", :error),
           []}
        end
    end
  end

  defp generic_app_node(%State{} = state) do
    app = State.current_app(state)

    Node.vstack(
      :root,
      [
        Pane.new(
          id: :header,
          title: app_title(app),
          lines: [app_subtitle(app)],
          border_fg: :cyan
        ),
        Node.hstack(
          :content,
          [
            List.new(
              id: :resources,
              title: "Resources",
              items: resource_lines(state),
              selected: state.resource_cursor,
              border_fg: :yellow,
              meta: [focusable: true, region: Workbench.Mouse.region(:resources)]
            ),
            Detail.new(
              id: :detail,
              title: "Detail",
              lines: detail_lines(State.detail_for_selected_resource(state)),
              border_fg: :green
            )
          ],
          constraints: [{:percentage, 42}, {:percentage, 58}]
        ),
        Help.new(
          id: :help,
          title: "Keys",
          lines: ["Up/Down select resource  ·  Esc back  ·  Ctrl+Q quit"],
          border_fg: :dark_gray
        ),
        status_node(state)
      ],
      constraints: [{:length, 3}, {:min, 8}, {:length, 3}, {:length, 1}]
    )
  end

  defp delegate_to_component(msg, %State{} = state, %Context{} = ctx) do
    case State.current_app_component_module(state) do
      nil ->
        :unhandled

      module ->
        child_ctx = child_context(ctx, state)
        child_props = child_props(state)
        child_state = State.current_app_component_state(state)

        case module.update(msg, child_state, child_props, child_ctx) do
          {:ok, next_child_state, cmds} ->
            {:ok,
             State.put_app_component_state(state, state.shell.selected_app_id, next_child_state),
             cmds}

          :unhandled ->
            :unhandled
        end
    end
  end

  defp delegate_info(msg, %State{} = state, %Context{} = ctx) do
    with module when not is_nil(module) <- State.current_app_component_module(state),
         true <- function_exported?(module, :handle_info, 4),
         {:ok, next_child_state, cmds} <- component_handle_info(module, msg, state, ctx) do
      {:ok, State.put_app_component_state(state, state.shell.selected_app_id, next_child_state),
       cmds}
    else
      nil -> :unhandled
      false -> :unhandled
      :unhandled -> :unhandled
    end
  end

  defp child_props(%State{} = state) do
    %{
      app: State.current_app(state),
      context: state.context,
      snapshot: state.snapshot
    }
  end

  defp child_context(%Context{} = ctx, %State{} = state) do
    %{ctx | path: ctx.path ++ [{:app, state.shell.selected_app_id}]}
  end

  defp component_handle_info(module, msg, %State{} = state, %Context{} = ctx) do
    module.handle_info(
      msg,
      State.current_app_component_state(state),
      child_props(state),
      child_context(ctx, state)
    )
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

  defp status_node(%State{} = state) do
    StatusBar.new(
      id: :status,
      text: state.status_line,
      style: status_style(state.status_severity)
    )
  end

  defp status_style(:error), do: %Style{fg: :red, modifiers: [:bold]}
  defp status_style(:warn), do: %Style{fg: :yellow}
  defp status_style(_severity), do: %Style{fg: :green}

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

  defp detail_lines(nil), do: ["No detail available."]

  defp detail_lines(%{sections: sections, recommended_actions: recommended_actions}) do
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

    body ++ recommendations
  end
end
