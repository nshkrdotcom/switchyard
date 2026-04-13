defmodule WorkbenchTuiFrameworkTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Event
  alias ExRatatui.Layout.Rect
  alias ExRatatui.Widgets.{Paragraph, WidgetList}
  alias Workbench.{Cmd, Context, EffectRunner, Keymap, Node, RenderTree}
  alias Workbench.Renderer.ExRatatui, as: ExRatatuiRenderer

  defmodule RuntimeOptsComponent do
    @behaviour Workbench.Component

    alias Workbench.{Cmd, Node}

    @impl true
    def init(_props, _ctx) do
      {:ok, %{phase: :boot}, commands: Cmd.message(:boot), render?: false, trace?: true}
    end

    @impl true
    def update(:advance, state, _props, _ctx) do
      {:ok, %{state | phase: :advanced}, commands: [], render?: false, trace?: false}
    end

    def update(_msg, _state, _props, _ctx), do: :unhandled

    @impl true
    def render(_state, _props, _ctx), do: Node.text(:runtime, "runtime")
  end

  defmodule SupervisedStopComponent do
    @behaviour Workbench.Component

    alias Workbench.Node

    @impl true
    def init(_props, _ctx), do: {:ok, %{phase: :boot}, []}

    @impl true
    def update(:advance, state, _props, _ctx) do
      {:ok, %{state | phase: :advanced}, render?: false}
    end

    def update(:stop, state, _props, _ctx) do
      {:stop, %{state | phase: :stopping}, trace?: false}
    end

    def update(_msg, _state, _props, _ctx), do: :unhandled

    @impl true
    def handle_info(:stop, state, _props, _ctx) do
      {:stop, %{state | phase: :info_stopping}, render?: false}
    end

    def handle_info(_msg, _state, _props, _ctx), do: :unhandled

    @impl true
    def render(_state, _props, _ctx), do: Node.text(:supervised, "supervised")
  end

  defmodule InfoRuntimeOptsComponent do
    @behaviour Workbench.Component

    alias Workbench.Node

    @impl true
    def init(_props, _ctx), do: {:ok, %{events: []}, []}

    @impl true
    def update(_msg, _state, _props, _ctx), do: :unhandled

    @impl true
    def handle_info(:tick, state, _props, _ctx) do
      {:ok, %{state | events: [:tick | state.events]}, render?: false, trace?: true}
    end

    def handle_info(_msg, _state, _props, _ctx), do: :unhandled

    @impl true
    def render(_state, _props, _ctx), do: Node.text(:info, "info")
  end

  defmodule MountedChildComponent do
    @behaviour Workbench.Component

    alias Workbench.{Cmd, Keymap, Node, Subscription}

    @impl true
    def init(props, ctx) do
      {:ok, %{messages: []},
       commands: Cmd.message({:child_init, Map.get(props, :label), ctx.path})}
    end

    @impl true
    def update(:child_ping, state, _props, _ctx) do
      {:ok, %{state | messages: [:ping | state.messages]},
       commands: Cmd.message({:child_updated, :ping})}
    end

    def update(_msg, _state, _props, _ctx), do: :unhandled

    @impl true
    def handle_info({:child_external, value}, state, _props, _ctx) do
      {:ok, %{state | messages: [value | state.messages]},
       commands: Cmd.message({:child_info, value})}
    end

    def handle_info(_msg, _state, _props, _ctx), do: :unhandled

    @impl true
    def render(_state, props, _ctx), do: Node.text(:child, Map.get(props, :label, "child"))

    @impl true
    def keymap(_state, _props, _ctx) do
      [
        Keymap.binding(
          id: :child_ping,
          keys: [Keymap.key("x", [])],
          description: "Ping child",
          message: :child_ping
        )
      ]
    end

    @impl true
    def subscriptions(_state, _props, _ctx) do
      [Subscription.interval(:child_tick, 250, :child_tick)]
    end
  end

  defmodule RootWithMountedChild do
    @behaviour Workbench.Component

    alias Workbench.Node

    @impl true
    def init(_props, _ctx), do: {:ok, %{mounted?: true}, []}

    @impl true
    def update(_msg, _state, _props, _ctx), do: :unhandled

    @impl true
    def handle_info(_msg, _state, _props, _ctx), do: :unhandled

    @impl true
    def render(%{mounted?: true}, _props, _ctx) do
      Node.component(:mounted_child, MountedChildComponent, %{label: "mounted child"})
    end

    def render(_state, _props, _ctx), do: Node.text(:empty, "empty")
  end

  defmodule SupervisedMountedChildComponent do
    @behaviour Workbench.Component

    alias Workbench.{Cmd, Node, Subscription}

    @impl true
    def mode, do: :supervised

    @impl true
    def init(props, _ctx) do
      {:ok, %{messages: []},
       commands: Cmd.message({:supervised_child_init, Map.get(props, :label)})}
    end

    @impl true
    def update(_msg, _state, _props, _ctx), do: :unhandled

    @impl true
    def handle_info({:supervised_child, value}, state, _props, _ctx) do
      {:ok, %{state | messages: [value | state.messages]},
       commands: Cmd.message({:supervised_child_info, value}), render?: false}
    end

    def handle_info(_msg, _state, _props, _ctx), do: :unhandled

    @impl true
    def subscriptions(_state, _props, _ctx) do
      [Subscription.interval(:supervised_child_tick, 250, {:supervised_child, :tick})]
    end

    @impl true
    def render(state, props, _ctx) do
      line =
        case state.messages do
          [latest | _rest] -> "#{Map.get(props, :label, "supervised")}: #{latest}"
          [] -> Map.get(props, :label, "supervised")
        end

      Node.text(:supervised_child, line)
    end
  end

  defmodule RootWithMountedSupervisedChild do
    @behaviour Workbench.Component

    alias Workbench.Node

    @impl true
    def init(_props, _ctx), do: {:ok, %{}, []}

    @impl true
    def update(_msg, _state, _props, _ctx), do: :unhandled

    @impl true
    def handle_info(_msg, _state, _props, _ctx), do: :unhandled

    @impl true
    def render(_state, _props, _ctx) do
      Node.component(
        :mounted_supervised_child,
        SupervisedMountedChildComponent,
        %{label: "supervised mounted"},
        mode: Workbench.Component.mode(SupervisedMountedChildComponent)
      )
    end
  end

  test "matches key events against structured bindings" do
    bindings = [
      Keymap.binding(
        id: :quit,
        keys: [Keymap.key("q", ["ctrl"])],
        description: "Quit",
        message: :quit
      )
    ]

    assert :quit = Keymap.match_event(bindings, %Event.Key{code: "q", modifiers: ["ctrl"]})
    assert nil == Keymap.match_event(bindings, %Event.Key{code: "q", modifiers: []})
  end

  test "resolves a vertical layout tree into concrete areas" do
    node =
      Node.vstack(:root, [Node.text(:header, "Header"), Node.text(:body, "Body")],
        constraints: [{:length, 2}, {:min, 3}]
      )

    tree = RenderTree.resolve(node, %Rect{x: 0, y: 0, width: 80, height: 10})

    assert length(tree.flat) == 3
    assert Enum.at(tree.flat, 1).area.height == 2
    assert Enum.at(tree.flat, 2).area.height >= 3
  end

  test "applies layout padding before splitting child areas" do
    node =
      Node.vstack(:root, [Node.text(:header, "Header"), Node.text(:body, "Body")],
        padding: {1, 2, 1, 1},
        constraints: [{:length, 2}, {:min, 3}]
      )

    tree = RenderTree.resolve(node, %Rect{x: 0, y: 0, width: 80, height: 10})

    assert Enum.at(tree.flat, 1).area == %Rect{x: 1, y: 1, width: 77, height: 2}
    assert Enum.at(tree.flat, 2).area.x == 1
    assert Enum.at(tree.flat, 2).area.width == 77
    assert Enum.at(tree.flat, 2).area.y == 3
  end

  test "maps framework request commands onto ExRatatui async commands" do
    ctx = %Context{request_handler: fn request, _opts -> {:ok, request} end}
    commands = EffectRunner.run([Cmd.request(:ping, [], &{:handled, &1})], ctx)

    assert [%ExRatatui.Command{kind: :async}] = commands
  end

  test "passes runtime opts through init and update" do
    assert {:ok, %Workbench.Runtime.State{} = state, init_opts} =
             Workbench.Runtime.init(RuntimeOptsComponent, [])

    assert init_opts[:render?] == false
    assert init_opts[:trace?] == true
    assert [%ExRatatui.Command{kind: :message}] = init_opts[:commands]

    assert {:noreply, %Workbench.Runtime.State{} = next_state, update_opts} =
             Workbench.Runtime.update({:info, {:workbench_root, :advance}}, state)

    assert next_state.root_state.phase == :advanced
    assert update_opts[:render?] == false
    assert update_opts[:trace?] == false
    assert update_opts[:commands] == []
  end

  test "renders workbench widget lists as ex_ratatui widget lists" do
    node =
      Node.widget(:trace, Workbench.Widgets.WidgetList, %{
        title: "Trace",
        scroll_offset: 2,
        items: [
          {Node.widget(:one, Workbench.Widgets.Pane, %{title: "One", lines: ["alpha", "beta"]}),
           4},
          {Node.text(:two, "gamma"), 1}
        ]
      })

    tree = RenderTree.resolve(node, %Rect{x: 0, y: 0, width: 80, height: 20})

    assert [{%WidgetList{} = widget, %Rect{width: 80, height: 20}}] =
             ExRatatuiRenderer.render(tree, [])

    assert widget.scroll_offset == 2
    assert [{%Paragraph{}, 4}, {%Paragraph{text: "gamma"}, 1}] = widget.items
  end

  test "lowers node style and theme tokens into widget rendering" do
    node =
      Node.widget(:styled, Workbench.Widgets.Pane, %{title: "Styled", lines: ["body"]})
      |> Workbench.Style.fg(:accent)
      |> Workbench.Style.border_fg(:warning)
      |> Workbench.Style.padding({2, 1, 0, 0})
      |> Workbench.Style.align(:center)
      |> Workbench.Style.weight(:bold)

    tree = RenderTree.resolve(node, %Rect{x: 0, y: 0, width: 40, height: 8})

    assert [{%Paragraph{} = widget, %Rect{width: 40, height: 8}}] =
             ExRatatuiRenderer.render(tree, theme: %{accent: :light_cyan, warning: :yellow})

    assert widget.style == %ExRatatui.Style{fg: :light_cyan, bg: nil, modifiers: [:bold]}
    assert widget.alignment == :center

    assert %ExRatatui.Widgets.Block{
             border_style: %ExRatatui.Style{fg: :yellow},
             border_type: :rounded,
             padding: {2, 1, 0, 0}
           } = widget.block
  end

  test "does not render unresolved component mount nodes directly" do
    node = Node.component(:mounted, RuntimeOptsComponent, %{})

    tree = RenderTree.resolve(node, %Rect{x: 0, y: 0, width: 80, height: 20})

    assert ExRatatuiRenderer.render(tree, []) == []
  end

  test "runtime mounts child components and returns child init commands" do
    assert {:ok, %Workbench.Runtime.State{} = state, init_opts} =
             Workbench.Runtime.init(RootWithMountedChild, [])

    assert [%ExRatatui.Command{kind: :message}] = init_opts[:commands]
    assert map_size(state.component_registry) == 1

    assert [{%Paragraph{text: "mounted child"}, %Rect{width: 80, height: 20}}] =
             Workbench.Runtime.render(state, %ExRatatui.Frame{width: 80, height: 20})
  end

  test "runtime routes key and info events to mounted child components" do
    assert {:ok, %Workbench.Runtime.State{} = state, _init_opts} =
             Workbench.Runtime.init(RootWithMountedChild, [])

    assert {:noreply, %Workbench.Runtime.State{} = next_state, key_opts} =
             Workbench.Runtime.update(
               {:event, %Event.Key{code: "x", modifiers: [], kind: "press"}},
               state
             )

    assert [%ExRatatui.Command{kind: :message}] = key_opts[:commands]
    assert map_size(next_state.component_registry) == 1

    assert {:noreply, %Workbench.Runtime.State{} = final_state, info_opts} =
             Workbench.Runtime.update({:info, {:child_external, :observed}}, next_state)

    assert [%ExRatatui.Command{kind: :message}] = info_opts[:commands]

    subscriptions = Workbench.Runtime.subscriptions(final_state)
    assert [%ExRatatui.Subscription{id: :child_tick}] = subscriptions
  end

  test "runtime routes info and subscriptions through mounted supervised child components" do
    assert {:ok, %Workbench.Runtime.State{} = state, init_opts} =
             Workbench.Runtime.init(RootWithMountedSupervisedChild, [])

    assert [%ExRatatui.Command{kind: :message}] = init_opts[:commands]

    assert [%ExRatatui.Subscription{kind: :interval, id: :supervised_child_tick}] =
             Workbench.Runtime.subscriptions(state)

    assert {:noreply, %Workbench.Runtime.State{} = next_state, info_opts} =
             Workbench.Runtime.update({:info, {:supervised_child, :tick}}, state)

    assert info_opts[:render?] == false
    assert [%ExRatatui.Command{kind: :message}] = info_opts[:commands]

    assert %Workbench.Runtime.ComponentEntry{
             mode: :supervised,
             state: %{messages: [:tick]}
           } = next_state.component_registry[["root"]]

    assert [{%Paragraph{text: "supervised mounted: tick"}, %Rect{width: 80, height: 20}}] =
             Workbench.Runtime.render(next_state, %ExRatatui.Frame{width: 80, height: 20})
  end

  test "supervised component server ignores missing handle_info callbacks" do
    ctx = %Context{}
    {:ok, pid} = Workbench.ComponentServer.start_link(module: RuntimeOptsComponent, ctx: ctx)

    send(pid, :noop)
    Process.sleep(10)

    assert Process.alive?(pid)

    assert %Workbench.ComponentServer{
             state: %{phase: :boot},
             runtime_opts: %{
               commands: [%Cmd{kind: :message, payload: :boot}],
               render?: false,
               trace?: true
             }
           } =
             Workbench.ComponentServer.snapshot(pid)
  end

  test "supervised component server update returns retained runtime opts" do
    ctx = %Context{}
    {:ok, pid} = Workbench.ComponentServer.start_link(module: RuntimeOptsComponent, ctx: ctx)

    assert {:ok,
            %Workbench.ComponentServer{
              state: %{phase: :advanced},
              runtime_opts: %{commands: [], render?: false, trace?: false}
            }, %{commands: [], render?: false, trace?: false}} =
             Workbench.ComponentServer.update(pid, :advance, ctx)

    assert %Workbench.ComponentServer{
             state: %{phase: :advanced},
             runtime_opts: %{commands: [], render?: false, trace?: false}
           } = Workbench.ComponentServer.snapshot(pid)
  end

  test "supervised component server retains runtime opts returned from handle_info" do
    ctx = %Context{}
    {:ok, pid} = Workbench.ComponentServer.start_link(module: InfoRuntimeOptsComponent, ctx: ctx)

    send(pid, :tick)
    Process.sleep(10)

    assert %Workbench.ComponentServer{
             state: %{events: [:tick]},
             runtime_opts: %{commands: [], render?: false, trace?: true}
           } =
             Workbench.ComponentServer.snapshot(pid)
  end

  test "supervised component server handles stop tuples and returns final runtime opts" do
    ctx = %Context{}
    {:ok, pid} = Workbench.ComponentServer.start_link(module: SupervisedStopComponent, ctx: ctx)

    ref = Process.monitor(pid)

    assert {:stop,
            %Workbench.ComponentServer{
              state: %{phase: :stopping},
              runtime_opts: %{commands: [], render?: true, trace?: false}
            }, %{commands: [], render?: true, trace?: false}} =
             Workbench.ComponentServer.update(pid, :stop, ctx)

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

    {:ok, pid} = Workbench.ComponentServer.start_link(module: SupervisedStopComponent, ctx: ctx)
    ref = Process.monitor(pid)
    send(pid, :stop)

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
  end
end
