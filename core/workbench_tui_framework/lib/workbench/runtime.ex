defmodule Workbench.Runtime.State do
  @moduledoc "Runtime state container for thin Workbench-backed terminal apps."

  defstruct root_module: nil,
            root_props: %{},
            root_state: nil,
            request_handler: nil,
            app_env: %{},
            theme: %{},
            capabilities: %Workbench.Capabilities{},
            screen_mode: :fullscreen,
            viewport: {0, 0},
            transcript: %Workbench.Transcript{}

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
          transcript: Workbench.Transcript.t()
        }
end

defmodule Workbench.Runtime do
  @moduledoc "Framework runtime helpers used by thin product ExRatatui apps."

  alias ExRatatui.Event
  alias ExRatatui.Frame
  alias ExRatatui.Layout.Rect

  alias Workbench.{
    ActionRegistry,
    Context,
    EffectRunner,
    FocusTree,
    Keymap,
    RegionMap,
    Renderer,
    RenderTree,
    Runtime,
    RuntimeIndex,
    Screen,
    Subscription
  }

  @spec init(module(), keyword()) ::
          {:ok, Runtime.State.t(), keyword()} | {:error, term()}
  def init(root_module, opts) do
    props = Map.new(opts)

    state = %Runtime.State{
      root_module: root_module,
      root_props: props,
      request_handler: Keyword.get(opts, :request_handler),
      app_env: Map.new(opts),
      theme: Keyword.get(opts, :theme, %{}),
      screen_mode: Keyword.get(opts, :screen_mode, :fullscreen)
    }

    ctx = context_for(state, {0, 0})

    case root_module.init(props, ctx) do
      {:ok, root_state, cmds} ->
        runtime_state = %{state | root_state: root_state}
        {:ok, runtime_state, commands: EffectRunner.run(cmds, ctx)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec update(term(), Runtime.State.t()) ::
          {:noreply, Runtime.State.t(), keyword()} | {:stop, Runtime.State.t()}
  def update({:event, %Event.Resize{width: width, height: height}}, %Runtime.State{} = state) do
    {:noreply, %{state | viewport: {width, height}}}
  end

  def update({:event, %Event.Key{kind: "press"} = event}, %Runtime.State{} = state) do
    ctx = context_for(state, state.viewport)
    bindings = current_bindings(state, ctx)
    msg = Keymap.match_event(bindings, event) || {:key, event}
    dispatch_update(msg, state, ctx)
  end

  def update({:event, %Event.Mouse{} = event}, %Runtime.State{} = state) do
    ctx = context_for(state, state.viewport)
    dispatch_update({:mouse, event}, state, ctx)
  end

  def update({:event, _event}, %Runtime.State{} = state), do: {:noreply, state}

  def update({:info, {:workbench_print, line}}, %Runtime.State{} = state) when is_binary(line) do
    transcript = Workbench.Transcript.append(state.transcript, line)
    {:noreply, %{state | transcript: transcript}}
  end

  def update({:info, :quit}, %Runtime.State{} = state) do
    ctx = context_for(state, state.viewport)
    dispatch_update(:quit, state, ctx)
  end

  def update({:info, {:workbench_root, msg}}, %Runtime.State{} = state) do
    ctx = context_for(state, state.viewport)
    dispatch_update(msg, state, ctx)
  end

  def update({:info, :workbench_stop}, %Runtime.State{} = state), do: {:stop, state}

  def update({:info, {:workbench_focus, _path}}, %Runtime.State{} = state) do
    {:noreply, state}
  end

  def update({:info, msg}, %Runtime.State{} = state) do
    ctx = context_for(state, state.viewport)

    if function_exported?(state.root_module, :handle_info, 4) do
      case state.root_module.handle_info(msg, state.root_state, state.root_props, ctx) do
        {:ok, root_state, cmds} ->
          {:noreply, %{state | root_state: root_state}, commands: EffectRunner.run(cmds, ctx)}

        :unhandled ->
          {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  @spec render(Runtime.State.t(), Frame.t()) :: [{ExRatatui.widget(), Rect.t()}]
  def render(%Runtime.State{} = state, %Frame{width: width, height: height}) do
    viewport = {width, height}
    ctx = context_for(state, viewport)

    case state.root_module.render(state.root_state, state.root_props, ctx) do
      %Workbench.Node{} = node ->
        tree = RenderTree.resolve(node, %Rect{x: 0, y: 0, width: width, height: height})
        _focus_tree = FocusTree.build(tree)
        _region_map = RegionMap.build(tree)
        _runtime_index = build_runtime_index(state, ctx)
        Renderer.ExRatatui.render(tree, [])

      _other ->
        []
    end
  end

  @spec subscriptions(Runtime.State.t()) :: [ExRatatui.Subscription.t()]
  def subscriptions(%Runtime.State{} = state) do
    ctx = context_for(state, state.viewport)

    if function_exported?(state.root_module, :subscriptions, 3) do
      state.root_module.subscriptions(state.root_state, state.root_props, ctx)
      |> Elixir.List.wrap()
      |> Enum.map(&Subscription.to_ex_ratatui/1)
    else
      []
    end
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

  defp dispatch_update(msg, %Runtime.State{} = state, %Context{} = ctx) do
    case state.root_module.update(msg, state.root_state, state.root_props, ctx) do
      {:ok, root_state, cmds} ->
        {:noreply, %{state | root_state: root_state}, commands: EffectRunner.run(cmds, ctx)}

      :unhandled ->
        {:noreply, state}

      {:stop, root_state} ->
        {:stop, %{state | root_state: root_state}}
    end
  end

  defp current_bindings(%Runtime.State{} = state, %Context{} = ctx) do
    if function_exported?(state.root_module, :keymap, 3) do
      state.root_module.keymap(state.root_state, state.root_props, ctx)
    else
      []
    end
  end

  defp current_actions(%Runtime.State{} = state, %Context{} = ctx) do
    if function_exported?(state.root_module, :actions, 3) do
      state.root_module.actions(state.root_state, state.root_props, ctx)
    else
      []
    end
  end

  defp build_runtime_index(%Runtime.State{} = state, %Context{} = ctx) do
    %RuntimeIndex{
      keybindings: current_bindings(state, ctx),
      actions: ActionRegistry.build([], current_actions(state, ctx)),
      subscriptions:
        if function_exported?(state.root_module, :subscriptions, 3) do
          state.root_module.subscriptions(state.root_state, state.root_props, ctx)
        else
          []
        end
    }
  end

  defp context_for(%Runtime.State{} = state, {width, height}) do
    %Context{
      theme: state.theme,
      screen: %Screen{mode: state.screen_mode, width: width, height: height},
      capabilities: state.capabilities,
      path: ["root"],
      request_handler: state.request_handler,
      app_env: state.app_env
    }
  end
end
