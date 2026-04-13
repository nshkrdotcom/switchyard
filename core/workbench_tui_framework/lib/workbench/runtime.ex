defmodule Workbench.Runtime.ComponentEntry do
  @moduledoc false

  defstruct path: [],
            module: nil,
            mode: :pure,
            props: %{},
            state: nil,
            pid: nil,
            runtime_opts: %{commands: [], render?: true, trace?: nil}

  @type t :: %__MODULE__{
          path: [term()],
          module: module(),
          mode: :pure | :supervised,
          props: map(),
          state: term(),
          pid: pid() | nil,
          runtime_opts: %{commands: [Workbench.Cmd.t()], render?: boolean(), trace?: term()}
        }
end

defmodule Workbench.Runtime.State do
  @moduledoc "Runtime state container for thin Workbench-backed terminal apps."

  @typedoc "Mounted-component registry entry shape stored in runtime state."
  @type component_registry_entry :: %{
          path: [term()],
          module: module(),
          mode: :pure | :supervised,
          props: map(),
          state: term(),
          pid: pid() | nil,
          runtime_opts: %{commands: [Workbench.Cmd.t()], render?: boolean(), trace?: term()}
        }

  @typedoc "Runtime-owned debug configuration and bounded session history."
  @type devtools_state :: %{
          enabled?: boolean(),
          history_limit: pos_integer(),
          artifact_dir: String.t() | nil,
          session_label: String.t(),
          sink: (map() -> term()) | nil,
          sequence: non_neg_integer(),
          events: [map()],
          commands: [map()],
          snapshots: [map()],
          latest: map() | nil
        }

  defstruct root_module: nil,
            root_props: %{},
            root_state: nil,
            request_handler: nil,
            app_env: %{},
            theme: %{},
            capabilities: %Workbench.Capabilities{},
            screen_mode: :fullscreen,
            viewport: {0, 0},
            transcript: %Workbench.Transcript{},
            component_supervisor: nil,
            component_registry: %{},
            devtools: %{
              enabled?: false,
              history_limit: 50,
              artifact_dir: nil,
              session_label: "workbench",
              sink: nil,
              sequence: 0,
              events: [],
              commands: [],
              snapshots: [],
              latest: nil
            }

  @type t :: %__MODULE__{
          root_module: module() | nil,
          root_props: map(),
          root_state: term(),
          request_handler: (term(), keyword() -> term()) | nil,
          app_env: map(),
          theme: map(),
          capabilities: Workbench.Capabilities.t(),
          screen_mode: :fullscreen | :inline | :mixed,
          viewport: {non_neg_integer(), non_neg_integer()},
          transcript: Workbench.Transcript.t(),
          component_supervisor: pid() | nil,
          component_registry: %{optional([term()]) => component_registry_entry()},
          devtools: devtools_state()
        }
end

defmodule Workbench.Runtime do
  @moduledoc "Framework runtime helpers used by thin Workbench-backed terminal apps."

  alias ExRatatui.Event
  alias ExRatatui.Frame
  alias ExRatatui.Layout.Rect

  alias Workbench.{
    ActionRegistry,
    Cmd,
    ComponentSupervisor,
    Context,
    EffectRunner,
    FocusTree,
    Keymap,
    RegionMap,
    Renderer,
    RenderTree,
    Runtime,
    Runtime.ComponentEntry,
    RuntimeIndex,
    Screen,
    Subscription
  }

  @spec init(module(), keyword()) ::
          {:ok, Runtime.State.t(), keyword()} | {:error, term()}
  def init(root_module, opts) do
    props = Map.new(opts)
    {:ok, component_supervisor} = ComponentSupervisor.start_link()

    state = %Runtime.State{
      root_module: root_module,
      root_props: props,
      request_handler: Keyword.get(opts, :request_handler),
      app_env: Map.new(opts),
      theme: Keyword.get(opts, :theme, %{}),
      screen_mode: Keyword.get(opts, :screen_mode, :fullscreen),
      component_supervisor: component_supervisor,
      devtools: normalize_devtools_opts(Keyword.get(opts, :devtools))
    }

    ctx = context_for(state, {0, 0})

    case root_module.init(props, ctx) do
      {:ok, root_state, runtime_opts} ->
        runtime_state = %{state | root_state: root_state}
        {runtime_state, mount_opts} = sync_component_registry(runtime_state, ctx)

        combined_opts =
          runtime_opts
          |> normalize_runtime_opts(ctx)
          |> merge_runtime_opts(mount_opts)

        runtime_state =
          maybe_capture_devtools(runtime_state, ctx, combined_opts, %{
            kind: :init,
            module: inspect(root_module)
          })

        {:ok, runtime_state, encode_runtime_opts(combined_opts)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec update(term(), Runtime.State.t()) ::
          {:noreply, Runtime.State.t(), keyword()}
          | {:noreply, Runtime.State.t()}
          | {:stop, Runtime.State.t()}
          | {:stop, Runtime.State.t(), keyword()}
  def update({:event, %Event.Resize{width: width, height: height}}, %Runtime.State{} = state) do
    next_state = %{state | viewport: {width, height}}
    ctx = context_for(next_state, next_state.viewport)
    {next_state, mount_opts} = sync_component_registry(next_state, ctx)

    next_state =
      maybe_capture_devtools(next_state, ctx, mount_opts, %{
        kind: :resize,
        width: width,
        height: height
      })

    {:noreply, next_state, encode_runtime_opts(mount_opts)}
  end

  def update({:event, %Event.Key{kind: "press"} = event}, %Runtime.State{} = state) do
    ctx = context_for(state, state.viewport)
    bindings = current_bindings(state, ctx)
    msg = Keymap.match_event(bindings, event) || {:key, event}

    dispatch_update(msg, state, ctx, %{
      kind: :key,
      code: event.code,
      modifiers: event.modifiers,
      resolved: summarize_value(msg)
    })
  end

  def update({:event, %Event.Mouse{} = event}, %Runtime.State{} = state) do
    ctx = context_for(state, state.viewport)

    dispatch_update({:mouse, event}, state, ctx, %{
      kind: :mouse,
      button: event.button,
      mouse_kind: event.kind,
      x: event.x,
      y: event.y,
      modifiers: event.modifiers,
      resolved: summarize_value({:mouse, event})
    })
  end

  def update({:event, _event}, %Runtime.State{} = state), do: {:noreply, state}

  def update({:info, {:workbench_print, line}}, %Runtime.State{} = state) when is_binary(line) do
    transcript = Workbench.Transcript.append(state.transcript, line)
    {:noreply, %{state | transcript: transcript}}
  end

  def update({:info, :quit}, %Runtime.State{} = state) do
    ctx = context_for(state, state.viewport)
    dispatch_update(:quit, state, ctx, %{kind: :info, message: ":quit"})
  end

  def update({:info, {:workbench_root, msg}}, %Runtime.State{} = state) do
    ctx = context_for(state, state.viewport)
    dispatch_update(msg, state, ctx, %{kind: :info, message: summarize_value(msg)})
  end

  def update({:info, {:workbench_component, path, msg}}, %Runtime.State{} = state)
      when is_list(path) do
    ctx = context_for(state, state.viewport)

    dispatch_component_update(
      msg,
      state,
      ctx,
      [target_path: path],
      %{kind: :component_info, target_path: inspect_path(path), message: summarize_value(msg)}
    )
  end

  def update({:info, {:workbench_devtools_snapshot_request, reply_to}}, %Runtime.State{} = state)
      when is_pid(reply_to) do
    send(reply_to, {:workbench_devtools_snapshot, public_devtools_state(state.devtools)})
    {:noreply, state}
  end

  def update({:info, :workbench_stop}, %Runtime.State{} = state), do: {:stop, state}

  def update({:info, {:workbench_focus, _path}}, %Runtime.State{} = state) do
    {:noreply, state}
  end

  def update({:info, msg}, %Runtime.State{} = state) do
    ctx = context_for(state, state.viewport)

    if function_exported?(state.root_module, :handle_info, 4) do
      case state.root_module.handle_info(msg, state.root_state, state.root_props, ctx) do
        {:ok, root_state, runtime_opts} ->
          handle_root_transition(
            state,
            root_state,
            runtime_opts,
            ctx,
            %{kind: :info, message: summarize_value(msg)}
          )

        {:stop, root_state} ->
          {:stop, %{state | root_state: root_state}}

        {:stop, root_state, runtime_opts} ->
          {:stop, %{state | root_state: root_state},
           runtime_opts |> normalize_runtime_opts(ctx) |> encode_runtime_opts()}

        :unhandled ->
          dispatch_component_info(
            msg,
            state,
            ctx,
            [],
            %{kind: :info, message: summarize_value(msg)}
          )
      end
    else
      dispatch_component_info(
        msg,
        state,
        ctx,
        [],
        %{kind: :info, message: summarize_value(msg)}
      )
    end
  end

  @spec render(Runtime.State.t(), Frame.t()) :: [{ExRatatui.widget(), Rect.t()}]
  def render(%Runtime.State{} = state, %Frame{width: width, height: height}) do
    viewport = {width, height}
    ctx = context_for(state, viewport)

    case render_root_node(state, ctx) do
      %Workbench.Node{} = node ->
        expanded = expand_component_nodes(node, state, ctx, ["root"])
        tree = RenderTree.resolve(expanded, %Rect{x: 0, y: 0, width: width, height: height})
        _focus_tree = FocusTree.build(tree)
        _region_map = RegionMap.build(tree)
        _runtime_index = build_runtime_index(state, ctx)
        Renderer.ExRatatui.render(tree, theme: ctx.theme)

      _other ->
        []
    end
  end

  @spec subscriptions(Runtime.State.t()) :: [ExRatatui.Subscription.t()]
  def subscriptions(%Runtime.State{} = state) do
    ctx = context_for(state, state.viewport)

    (root_subscriptions(state, ctx) ++ mounted_subscriptions(state, ctx))
    |> Enum.map(&Subscription.to_ex_ratatui/1)
  end

  @spec render_accessible(Runtime.State.t()) ::
          Workbench.Accessibility.Node.t()
          | [Workbench.Accessibility.Node.t()]
          | :unsupported
  def render_accessible(%Runtime.State{} = state) do
    ctx = context_for(state, state.viewport)

    if function_exported?(state.root_module, :render_accessible, 3) do
      state.root_module.render_accessible(state.root_state, state.root_props, ctx)
    else
      :unsupported
    end
  end

  defp dispatch_update(msg, %Runtime.State{} = state, %Context{} = ctx, trigger) do
    case state.root_module.update(msg, state.root_state, state.root_props, ctx) do
      {:ok, root_state, runtime_opts} ->
        handle_root_transition(state, root_state, runtime_opts, ctx, trigger)

      :unhandled ->
        dispatch_component_update(msg, state, ctx, [], trigger)

      {:stop, root_state} ->
        {:stop, %{state | root_state: root_state}}

      {:stop, root_state, runtime_opts} ->
        {:stop, %{state | root_state: root_state},
         runtime_opts |> normalize_runtime_opts(ctx) |> encode_runtime_opts()}
    end
  end

  defp handle_root_transition(
         %Runtime.State{} = state,
         root_state,
         runtime_opts,
         %Context{} = ctx,
         trigger
       ) do
    next_state = %{state | root_state: root_state}
    {next_state, mount_opts} = sync_component_registry(next_state, ctx)
    combined_opts = runtime_opts |> normalize_runtime_opts(ctx) |> merge_runtime_opts(mount_opts)
    next_state = maybe_capture_devtools(next_state, ctx, combined_opts, trigger)
    {:noreply, next_state, encode_runtime_opts(combined_opts)}
  end

  defp dispatch_component_update(msg, %Runtime.State{} = state, %Context{} = ctx, opts, trigger) do
    case route_component_update(msg, state, ctx, opts) do
      {:ok, next_state, runtime_opts} ->
        {next_state, mount_opts} = sync_component_registry(next_state, ctx)
        combined_opts = merge_runtime_opts(runtime_opts, mount_opts)
        next_state = maybe_capture_devtools(next_state, ctx, combined_opts, trigger)

        {:noreply, next_state, encode_runtime_opts(combined_opts)}

      :unhandled ->
        {:noreply, state}
    end
  end

  defp dispatch_component_info(msg, %Runtime.State{} = state, %Context{} = ctx, opts, trigger) do
    case route_component_info(msg, state, ctx, opts) do
      {:ok, next_state, runtime_opts} ->
        {next_state, mount_opts} = sync_component_registry(next_state, ctx)
        combined_opts = merge_runtime_opts(runtime_opts, mount_opts)
        next_state = maybe_capture_devtools(next_state, ctx, combined_opts, trigger)

        {:noreply, next_state, encode_runtime_opts(combined_opts)}

      :unhandled ->
        {:noreply, state}
    end
  end

  defp route_component_update(msg, %Runtime.State{} = state, %Context{} = ctx, opts) do
    route_component_transition(state, ctx, opts, fn entry, child_ctx ->
      update_component_entry(entry, msg, child_ctx)
    end)
  end

  defp route_component_info(msg, %Runtime.State{} = state, %Context{} = ctx, opts) do
    route_component_transition(state, ctx, opts, fn entry, child_ctx ->
      handle_info_component_entry(entry, msg, child_ctx)
    end)
  end

  defp route_component_transition(
         %Runtime.State{} = state,
         %Context{} = ctx,
         opts,
         router
       ) do
    state
    |> dispatch_paths(opts)
    |> Enum.find_value(:unhandled, fn path ->
      case Map.get(state.component_registry, path) do
        nil -> nil
        entry -> route_component_entry(state, ctx, path, entry, router)
      end
    end)
  end

  defp route_component_entry(%Runtime.State{} = state, %Context{} = ctx, path, entry, router) do
    child_ctx = child_context(ctx, path)

    case router.(entry, child_ctx) do
      :unhandled ->
        nil

      {:ok, next_entry, runtime_opts} ->
        {:ok, put_component_entry(state, next_entry),
         normalize_runtime_opts(runtime_opts, child_ctx)}

      {:stop, next_entry, runtime_opts} ->
        {:ok, delete_component_entry(state, next_entry),
         normalize_runtime_opts(runtime_opts, child_ctx)}
    end
  end

  defp update_component_entry(
         %ComponentEntry{mode: :supervised, pid: pid, path: path},
         msg,
         %Context{} = ctx
       ) do
    case Workbench.ComponentServer.update(pid, msg, ctx) do
      {:ok, snapshot, runtime_opts} ->
        {:ok, entry_from_snapshot(path, pid, snapshot), runtime_opts}

      {:stop, snapshot} ->
        {:stop, entry_from_snapshot(path, pid, snapshot), default_component_runtime_opts()}

      {:stop, snapshot, runtime_opts} ->
        {:stop, entry_from_snapshot(path, pid, snapshot), runtime_opts}

      :unhandled ->
        :unhandled
    end
  end

  defp update_component_entry(%ComponentEntry{mode: :pure} = entry, msg, %Context{} = ctx) do
    case entry.module.update(msg, entry.state, entry.props, ctx) do
      {:ok, next_state, runtime_opts} ->
        {:ok,
         %{
           entry
           | state: next_state,
             runtime_opts: normalize_component_runtime_opts(runtime_opts)
         }, runtime_opts}

      {:stop, next_state} ->
        {:stop, %{entry | state: next_state, runtime_opts: default_component_runtime_opts()},
         default_component_runtime_opts()}

      {:stop, next_state, runtime_opts} ->
        {:stop,
         %{
           entry
           | state: next_state,
             runtime_opts: normalize_component_runtime_opts(runtime_opts)
         }, runtime_opts}

      :unhandled ->
        :unhandled
    end
  end

  defp handle_info_component_entry(
         %ComponentEntry{mode: :supervised, pid: pid, path: path},
         msg,
         %Context{} = ctx
       ) do
    case Workbench.ComponentServer.handle_info(pid, msg, ctx) do
      {:ok, snapshot, runtime_opts} ->
        {:ok, entry_from_snapshot(path, pid, snapshot), runtime_opts}

      {:stop, snapshot} ->
        {:stop, entry_from_snapshot(path, pid, snapshot), default_component_runtime_opts()}

      {:stop, snapshot, runtime_opts} ->
        {:stop, entry_from_snapshot(path, pid, snapshot), runtime_opts}

      :unhandled ->
        :unhandled
    end
  end

  defp handle_info_component_entry(%ComponentEntry{mode: :pure} = entry, msg, %Context{} = ctx) do
    if function_exported?(entry.module, :handle_info, 4) do
      case entry.module.handle_info(msg, entry.state, entry.props, ctx) do
        {:ok, next_state, runtime_opts} ->
          {:ok,
           %{
             entry
             | state: next_state,
               runtime_opts: normalize_component_runtime_opts(runtime_opts)
           }, runtime_opts}

        {:stop, next_state} ->
          {:stop, %{entry | state: next_state, runtime_opts: default_component_runtime_opts()},
           default_component_runtime_opts()}

        {:stop, next_state, runtime_opts} ->
          {:stop,
           %{
             entry
             | state: next_state,
               runtime_opts: normalize_component_runtime_opts(runtime_opts)
           }, runtime_opts}

        :unhandled ->
          :unhandled
      end
    else
      :unhandled
    end
  end

  defp current_bindings(%Runtime.State{} = state, %Context{} = ctx) do
    root_bindings =
      if function_exported?(state.root_module, :keymap, 3) do
        state.root_module.keymap(state.root_state, state.root_props, ctx)
      else
        []
      end

    root_bindings ++ mounted_bindings(state, ctx)
  end

  defp current_actions(%Runtime.State{} = state, %Context{} = ctx) do
    root_actions =
      if function_exported?(state.root_module, :actions, 3) do
        state.root_module.actions(state.root_state, state.root_props, ctx)
      else
        []
      end

    root_actions ++ mounted_actions(state, ctx)
  end

  defp build_runtime_index(%Runtime.State{} = state, %Context{} = ctx) do
    %RuntimeIndex{
      keybindings: current_bindings(state, ctx),
      actions: ActionRegistry.build([], current_actions(state, ctx)),
      subscriptions: root_subscriptions(state, ctx) ++ mounted_subscriptions(state, ctx)
    }
  end

  defp root_subscriptions(%Runtime.State{} = state, %Context{} = ctx) do
    if function_exported?(state.root_module, :subscriptions, 3) do
      List.wrap(state.root_module.subscriptions(state.root_state, state.root_props, ctx))
    else
      []
    end
  end

  defp mounted_bindings(%Runtime.State{} = state, %Context{} = ctx) do
    state
    |> ordered_component_entries()
    |> Enum.flat_map(fn {path, entry} ->
      child_ctx = child_context(ctx, path)

      if function_exported?(entry.module, :keymap, 3) do
        entry.module.keymap(entry.state, entry.props, child_ctx)
      else
        []
      end
    end)
  end

  defp mounted_actions(%Runtime.State{} = state, %Context{} = ctx) do
    state
    |> ordered_component_entries()
    |> Enum.flat_map(fn {path, entry} ->
      child_ctx = child_context(ctx, path)

      if function_exported?(entry.module, :actions, 3) do
        entry.module.actions(entry.state, entry.props, child_ctx)
      else
        []
      end
    end)
  end

  defp mounted_subscriptions(%Runtime.State{} = state, %Context{} = ctx) do
    state
    |> ordered_component_entries()
    |> Enum.flat_map(fn {path, entry} ->
      child_ctx = child_context(ctx, path)

      if function_exported?(entry.module, :subscriptions, 3) do
        List.wrap(entry.module.subscriptions(entry.state, entry.props, child_ctx))
      else
        []
      end
    end)
  end

  defp ordered_component_entries(%Runtime.State{} = state) do
    Enum.sort_by(state.component_registry, fn {path, _entry} -> path end)
  end

  defp context_for(%Runtime.State{} = state, {width, height}, path \\ ["root"]) do
    %Context{
      theme: state.theme,
      screen: %Screen{mode: state.screen_mode, width: width, height: height},
      capabilities: state.capabilities,
      path: path,
      request_handler: state.request_handler,
      devtools: public_devtools_state(state.devtools),
      app_env: state.app_env
    }
  end

  defp child_context(%Context{} = ctx, path), do: %{ctx | path: path}

  defp render_root_node(%Runtime.State{} = state, %Context{} = ctx) do
    state.root_module.render(state.root_state, state.root_props, ctx)
  end

  defp sync_component_registry(%Runtime.State{} = state, %Context{} = ctx) do
    case render_root_node(state, ctx) do
      %Workbench.Node{} = node ->
        {registry, collected_opts} =
          discover_component_entries(
            node,
            state,
            ctx,
            ["root"],
            state.component_registry,
            %{},
            []
          )

        unmount_stale_entries(state.component_registry, registry, state.component_supervisor)
        {%{state | component_registry: registry}, merge_runtime_opts(collected_opts)}

      _other ->
        unmount_stale_entries(state.component_registry, %{}, state.component_supervisor)
        {%{state | component_registry: %{}}, default_runtime_opts()}
    end
  end

  defp discover_component_entries(
         %Workbench.Node{kind: :component} = node,
         %Runtime.State{} = state,
         %Context{} = ctx,
         path,
         old_registry,
         new_registry,
         collected_opts
       ) do
    component_path = path
    child_ctx = child_context(ctx, component_path)

    {entry, maybe_opts} =
      ensure_component_entry(
        Map.get(old_registry, component_path),
        node,
        child_ctx,
        state.component_supervisor
      )

    rendered = render_component_entry(entry, child_ctx, node.id)
    new_registry = Map.put(new_registry, component_path, entry)

    collected_opts =
      if is_nil(maybe_opts), do: collected_opts, else: [maybe_opts | collected_opts]

    discover_component_entries(
      rendered,
      state,
      child_ctx,
      component_path,
      old_registry,
      new_registry,
      collected_opts
    )
  end

  defp discover_component_entries(
         %Workbench.Node{children: children},
         %Runtime.State{} = state,
         %Context{} = ctx,
         path,
         old_registry,
         new_registry,
         collected_opts
       ) do
    Enum.reduce(children, {new_registry, collected_opts}, fn child, {registry_acc, opts_acc} ->
      child_path = path ++ [child.id || child.module || 0]

      discover_component_entries(
        child,
        state,
        ctx,
        child_path,
        old_registry,
        registry_acc,
        opts_acc
      )
    end)
  end

  defp ensure_component_entry(existing, %Workbench.Node{} = node, %Context{} = ctx, supervisor) do
    mode = Map.get(node.meta, :component_mode, Workbench.Component.mode(node.module))
    props = Map.new(node.props)

    if reusable_component_entry?(existing, node.module, mode, props) do
      {refresh_component_entry(existing), nil}
    else
      maybe_stop_component(existing, supervisor)
      mount_component_entry(node.module, mode, props, ctx, supervisor)
    end
  end

  defp reusable_component_entry?(%ComponentEntry{} = entry, module, mode, props) do
    entry.module == module and entry.mode == mode and entry.props == props
  end

  defp reusable_component_entry?(_other, _module, _mode, _props), do: false

  defp refresh_component_entry(%ComponentEntry{mode: :supervised, pid: pid, path: path}) do
    entry_from_snapshot(path, pid, Workbench.ComponentServer.snapshot(pid))
  end

  defp refresh_component_entry(%ComponentEntry{} = entry), do: entry

  defp mount_component_entry(module, :supervised, props, %Context{} = ctx, supervisor) do
    {:ok, pid} =
      ComponentSupervisor.start_component(supervisor, module: module, props: props, ctx: ctx)

    snapshot = Workbench.ComponentServer.snapshot(pid)
    entry = entry_from_snapshot(ctx.path, pid, snapshot)
    {entry, normalize_runtime_opts(entry.runtime_opts, ctx)}
  end

  defp mount_component_entry(module, _mode, props, %Context{} = ctx, _supervisor) do
    {:ok, component_state, runtime_opts} = module.init(props, ctx)

    entry = %ComponentEntry{
      path: ctx.path,
      module: module,
      mode: :pure,
      props: props,
      state: component_state,
      runtime_opts: normalize_component_runtime_opts(runtime_opts)
    }

    {entry, normalize_runtime_opts(runtime_opts, ctx)}
  end

  defp render_component_entry(%ComponentEntry{} = entry, %Context{} = ctx, mount_id) do
    case entry.module.render(entry.state, entry.props, ctx) do
      %Workbench.Node{} = node -> %{node | id: mount_id || node.id}
      _other -> Workbench.Node.new(id: mount_id)
    end
  end

  defp expand_component_nodes(
         %Workbench.Node{kind: :component} = node,
         %Runtime.State{} = state,
         %Context{} = ctx,
         path
       ) do
    component_path = path

    case Map.get(state.component_registry, component_path) do
      %ComponentEntry{} = entry ->
        entry
        |> render_component_entry(child_context(ctx, component_path), node.id)
        |> expand_component_nodes(state, child_context(ctx, component_path), component_path)

      nil ->
        node
    end
  end

  defp expand_component_nodes(
         %Workbench.Node{} = node,
         %Runtime.State{} = state,
         %Context{} = ctx,
         path
       ) do
    children =
      Enum.map(node.children, fn child ->
        child_path = path ++ [child.id || child.module || 0]
        expand_component_nodes(child, state, ctx, child_path)
      end)

    %{node | children: children}
  end

  defp unmount_stale_entries(old_registry, new_registry, supervisor) do
    old_registry
    |> Enum.reject(fn {path, _entry} -> Map.has_key?(new_registry, path) end)
    |> Enum.each(fn {_path, entry} -> maybe_stop_component(entry, supervisor) end)
  end

  defp maybe_stop_component(%ComponentEntry{mode: :supervised, pid: pid}, supervisor)
       when is_pid(pid) and is_pid(supervisor) do
    DynamicSupervisor.terminate_child(supervisor, pid)
    :ok
  end

  defp maybe_stop_component(_entry, _supervisor), do: :ok

  defp put_component_entry(%Runtime.State{} = state, %ComponentEntry{} = entry) do
    %{state | component_registry: Map.put(state.component_registry, entry.path, entry)}
  end

  defp delete_component_entry(%Runtime.State{} = state, %ComponentEntry{} = entry) do
    maybe_stop_component(entry, state.component_supervisor)
    %{state | component_registry: Map.delete(state.component_registry, entry.path)}
  end

  defp entry_from_snapshot(path, pid, %Workbench.ComponentServer{} = snapshot) do
    %ComponentEntry{
      path: path,
      module: snapshot.module,
      mode: Workbench.Component.mode(snapshot.module),
      props: snapshot.props,
      state: snapshot.state,
      pid: pid,
      runtime_opts: snapshot.runtime_opts
    }
  end

  defp dispatch_paths(%Runtime.State{} = state, opts) do
    case Keyword.get(opts, :target_path) do
      nil ->
        state.component_registry
        |> Map.keys()
        |> Enum.sort_by(&length/1, :desc)

      path when is_list(path) ->
        [path]
    end
  end

  defp normalize_devtools_opts(nil), do: default_devtools_state()
  defp normalize_devtools_opts(false), do: default_devtools_state()

  defp normalize_devtools_opts(true) do
    %{default_devtools_state() | enabled?: true}
  end

  defp normalize_devtools_opts(opts) when is_list(opts) do
    opts
    |> Map.new()
    |> normalize_devtools_opts()
  end

  defp normalize_devtools_opts(%{} = opts) do
    enabled? = Map.get(opts, :enabled?, Map.get(opts, "enabled?", true))
    history_limit = Map.get(opts, :history_limit, Map.get(opts, "history_limit", 50))

    %{
      default_devtools_state()
      | enabled?: enabled?,
        history_limit: max(history_limit, 1),
        artifact_dir: Map.get(opts, :artifact_dir, Map.get(opts, "artifact_dir")),
        session_label: Map.get(opts, :session_label, Map.get(opts, "session_label", "workbench")),
        sink: Map.get(opts, :sink, Map.get(opts, "sink"))
    }
  end

  defp default_devtools_state do
    %{
      enabled?: false,
      history_limit: 50,
      artifact_dir: nil,
      session_label: "workbench",
      sink: nil,
      sequence: 0,
      events: [],
      commands: [],
      snapshots: [],
      latest: nil
    }
  end

  defp public_devtools_state(%{enabled?: false}), do: %{enabled?: false}

  defp public_devtools_state(devtools) do
    %{
      enabled?: true,
      artifact_dir: devtools.artifact_dir,
      session_label: devtools.session_label,
      history_limit: devtools.history_limit,
      events: devtools.events,
      commands: devtools.commands,
      snapshots: devtools.snapshots,
      latest: devtools.latest
    }
  end

  defp maybe_capture_devtools(
         %Runtime.State{devtools: %{enabled?: false}} = state,
         _ctx,
         _opts,
         _trigger
       ),
       do: state

  defp maybe_capture_devtools(
         %Runtime.State{} = state,
         %Context{} = ctx,
         runtime_opts,
         trigger
       ) do
    sequence = state.devtools.sequence + 1

    snapshot =
      derive_devtools_snapshot(
        state,
        ctx,
        runtime_opts,
        normalize_devtools_trigger(trigger),
        sequence
      )

    event_entry = %{sequence: sequence, at_ms: snapshot.at_ms, trigger: snapshot.trigger}

    command_entry = %{
      sequence: sequence,
      at_ms: snapshot.at_ms,
      commands: snapshot.commands,
      render?: snapshot.render?,
      trace?: snapshot.trace?
    }

    devtools = %{
      state.devtools
      | sequence: sequence,
        events:
          push_devtools_history(state.devtools.events, event_entry, state.devtools.history_limit),
        commands:
          push_devtools_history(
            state.devtools.commands,
            command_entry,
            state.devtools.history_limit
          ),
        snapshots:
          push_devtools_history(
            state.devtools.snapshots,
            snapshot,
            state.devtools.history_limit
          ),
        latest: snapshot
    }

    emit_devtools_entry(devtools.sink, %{kind: :event, entry: event_entry})
    emit_devtools_entry(devtools.sink, %{kind: :command, entry: command_entry})
    emit_devtools_entry(devtools.sink, %{kind: :snapshot, entry: snapshot})

    %{state | devtools: devtools}
  end

  defp derive_devtools_snapshot(
         %Runtime.State{} = state,
         %Context{} = ctx,
         runtime_opts,
         trigger,
         sequence
       ) do
    {render_tree, focus_tree, region_map, runtime_index} = derive_runtime_graphs(state, ctx)
    {width, height} = state.viewport

    %{
      sequence: sequence,
      at_ms: System.system_time(:millisecond),
      trigger: trigger,
      route: derive_route(state.root_state),
      root_module: inspect(state.root_module),
      root_state_summary: summarize_value(state.root_state),
      viewport: %{width: width, height: height},
      component_count: map_size(state.component_registry),
      component_paths:
        state.component_registry
        |> Map.keys()
        |> Enum.sort_by(&length/1)
        |> Enum.map(&inspect_path/1),
      render_tree_entries: render_tree_entry_count(render_tree),
      focus_count: focus_path_count(focus_tree),
      focus_paths: focus_tree_paths(focus_tree),
      region_count: region_count(region_map),
      subscription_count: length(runtime_index.subscriptions),
      subscriptions: Enum.map(runtime_index.subscriptions, &summarize_subscription/1),
      keybinding_count: length(runtime_index.keybindings),
      action_count: length(runtime_index.actions),
      commands: summarize_commands(runtime_opts.commands),
      render?: runtime_opts.render?,
      trace?: runtime_opts.trace?,
      transcript_tail: Enum.take(state.transcript.lines, -5),
      artifact_dir: state.devtools.artifact_dir
    }
  end

  defp derive_runtime_graphs(%Runtime.State{} = state, %Context{} = ctx) do
    case render_root_node(state, ctx) do
      %Workbench.Node{} = node ->
        expanded = expand_component_nodes(node, state, ctx, ["root"])
        render_tree = RenderTree.resolve(expanded, viewport_rect(ctx))
        focus_tree = FocusTree.build(render_tree)
        region_map = RegionMap.build(render_tree)
        runtime_index = build_runtime_index(state, ctx)
        {render_tree, focus_tree, region_map, runtime_index}

      _other ->
        {nil, %FocusTree{}, %RegionMap{}, build_runtime_index(state, ctx)}
    end
  end

  defp viewport_rect(%Context{screen: %Screen{width: width, height: height}}) do
    %Rect{x: 0, y: 0, width: width, height: height}
  end

  defp push_devtools_history(entries, entry, limit) do
    [entry | entries] |> Enum.take(limit)
  end

  defp emit_devtools_entry(nil, _entry), do: :ok

  defp emit_devtools_entry(sink, entry) when is_function(sink, 1) do
    _ = sink.(entry)
    :ok
  end

  defp normalize_devtools_trigger(%{kind: _kind} = trigger), do: trigger

  defp derive_route(root_state) do
    case Map.get(root_state || %{}, :shell) do
      %{route: route} -> route
      _other -> nil
    end
  end

  defp summarize_commands(commands) do
    commands
    |> List.wrap()
    |> Enum.map(fn command ->
      %{
        kind: Map.get(command, :kind, :unknown),
        message: summarize_value(Map.get(command, :message)),
        delay_ms: Map.get(command, :delay_ms),
        nested_count: command |> Map.get(:commands, []) |> List.wrap() |> length()
      }
    end)
  end

  defp summarize_subscription(subscription) do
    %{
      id: Map.get(subscription, :id),
      kind: Map.get(subscription, :kind),
      interval_ms: Map.get(subscription, :interval_ms),
      message: summarize_value(Map.get(subscription, :message))
    }
  end

  defp render_tree_entry_count(nil), do: 0
  defp render_tree_entry_count(%RenderTree{flat: flat}), do: length(flat)

  defp focus_path_count(%FocusTree{paths: paths}), do: length(paths)

  defp focus_tree_paths(%FocusTree{paths: paths}), do: Enum.map(paths, &inspect_path/1)

  defp region_count(%RegionMap{regions: regions}), do: length(regions)

  defp inspect_path(path) when is_list(path), do: Enum.map_join(path, " / ", &inspect/1)
  defp inspect_path(other), do: inspect(other)

  defp summarize_value(value) do
    inspect(value, pretty: false, limit: 10, printable_limit: 200)
  end

  defp default_component_runtime_opts do
    %{commands: [], render?: true, trace?: nil}
  end

  defp normalize_component_runtime_opts(nil), do: default_component_runtime_opts()

  defp normalize_component_runtime_opts(%Cmd{} = command) do
    %{default_component_runtime_opts() | commands: Cmd.normalize(command)}
  end

  defp normalize_component_runtime_opts(runtime_opts) when is_list(runtime_opts) do
    if Keyword.keyword?(runtime_opts) and
         Enum.any?(runtime_opts, fn {key, _value} -> key in [:commands, :render?, :trace?] end) do
      %{
        commands: runtime_opts |> Keyword.get(:commands, []) |> Cmd.normalize(),
        render?: Keyword.get(runtime_opts, :render?, true),
        trace?: Keyword.get(runtime_opts, :trace?)
      }
    else
      %{default_component_runtime_opts() | commands: Cmd.normalize(runtime_opts)}
    end
  end

  defp normalize_component_runtime_opts(%{} = runtime_opts) do
    %{
      commands:
        runtime_opts
        |> Map.get(:commands, Map.get(runtime_opts, "commands", []))
        |> Cmd.normalize(),
      render?: Map.get(runtime_opts, :render?, Map.get(runtime_opts, "render?", true)),
      trace?: Map.get(runtime_opts, :trace?, Map.get(runtime_opts, "trace?"))
    }
  end

  defp default_runtime_opts do
    %{commands: [], render?: true, trace?: nil}
  end

  defp normalize_runtime_opts(nil, _ctx), do: default_runtime_opts()

  defp normalize_runtime_opts(%Cmd{} = command, %Context{} = ctx) do
    %{default_runtime_opts() | commands: EffectRunner.run(command, ctx)}
  end

  defp normalize_runtime_opts(runtime_opts, %Context{} = ctx) when is_list(runtime_opts) do
    if Keyword.keyword?(runtime_opts) and
         Enum.any?(runtime_opts, fn {key, _value} -> key in [:commands, :render?, :trace?] end) do
      runtime_opts
      |> Map.new()
      |> normalize_runtime_opts(ctx)
    else
      %{default_runtime_opts() | commands: EffectRunner.run(runtime_opts, ctx)}
    end
  end

  defp normalize_runtime_opts(runtime_opts, %Context{} = ctx) when is_map(runtime_opts) do
    %{
      commands:
        runtime_opts
        |> Map.get(:commands, Map.get(runtime_opts, "commands", []))
        |> EffectRunner.run(ctx),
      render?: Map.get(runtime_opts, :render?, Map.get(runtime_opts, "render?", true)),
      trace?: Map.get(runtime_opts, :trace?, Map.get(runtime_opts, "trace?"))
    }
  end

  defp normalize_runtime_opts(other, _ctx) do
    raise ArgumentError, "invalid Workbench runtime opts: #{inspect(other)}"
  end

  defp encode_runtime_opts(runtime_opts) do
    [
      commands: runtime_opts.commands,
      render?: runtime_opts.render?,
      trace?: runtime_opts.trace?
    ]
  end

  defp merge_runtime_opts(runtime_opts_list) when is_list(runtime_opts_list) do
    Enum.reduce(runtime_opts_list, default_runtime_opts(), &merge_runtime_opts(&2, &1))
  end

  defp merge_runtime_opts(left, right) do
    %{
      commands: List.wrap(left.commands) ++ List.wrap(right.commands),
      render?: left.render? and right.render?,
      trace?: right.trace? || left.trace?
    }
  end
end
