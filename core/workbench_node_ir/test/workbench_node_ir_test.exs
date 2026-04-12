defmodule WorkbenchNodeIrTest do
  use ExUnit.Case, async: true

  alias Workbench.Node

  test "layout nodes preserve declared constraints" do
    node =
      Node.vstack(:root, [Node.text(:header, "Header"), Node.text(:body, "Body")],
        constraints: [{:length, 2}, {:min, 3}]
      )

    assert node.kind == :layout
    assert node.layout.direction == :vertical
    assert node.layout.constraints == [{:length, 2}, {:min, 3}]
  end

  test "widget nodes normalize keyword props and meta" do
    node = Node.widget(:pane, Workbench.Widgets.Pane, title: "Pane", meta: [focusable: true])

    assert node.kind == :widget
    assert node.props == %{meta: [focusable: true], title: "Pane"}
    assert node.meta == %{focusable: true}
  end
end
