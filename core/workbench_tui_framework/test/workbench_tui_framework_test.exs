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

  test "supervised component server ignores missing handle_info callbacks" do
    ctx = %Context{}
    {:ok, pid} = Workbench.ComponentServer.start_link(module: RuntimeOptsComponent, ctx: ctx)

    send(pid, :noop)
    Process.sleep(10)

    assert Process.alive?(pid)

    assert %Workbench.ComponentServer{state: %{phase: :boot}} =
             Workbench.ComponentServer.snapshot(pid)
  end

  test "supervised component server handles runtime opts and stop tuples" do
    ctx = %Context{}
    {:ok, pid} = Workbench.ComponentServer.start_link(module: SupervisedStopComponent, ctx: ctx)

    Workbench.ComponentServer.update(pid, :advance, ctx)
    Process.sleep(10)

    assert %Workbench.ComponentServer{state: %{phase: :advanced}} =
             Workbench.ComponentServer.snapshot(pid)

    ref = Process.monitor(pid)
    Workbench.ComponentServer.update(pid, :stop, ctx)

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

    {:ok, pid} = Workbench.ComponentServer.start_link(module: SupervisedStopComponent, ctx: ctx)
    ref = Process.monitor(pid)
    send(pid, :stop)

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
  end
end
