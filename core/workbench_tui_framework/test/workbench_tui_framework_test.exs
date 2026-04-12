defmodule WorkbenchTuiFrameworkTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Event
  alias ExRatatui.Layout.Rect
  alias Workbench.{Cmd, Context, EffectRunner, Keymap, Node, RenderTree}

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
end
