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

  test "component nodes preserve mount metadata separately from props" do
    node =
      Node.component(:mounted, Workbench.TestComponent, %{title: "Mounted"},
        mode: :supervised,
        meta: [focusable: true, restart: :transient]
      )

    assert node.kind == :component
    assert node.module == Workbench.TestComponent
    assert node.props == %{title: "Mounted"}
    assert node.meta == %{component_mode: :supervised, focusable: true, restart: :transient}
  end
end
