defmodule WorkbenchWidgetsTest do
  use ExUnit.Case, async: true

  alias Workbench.Widgets

  test "widget constructors return framework nodes bound to the widget module" do
    node = Widgets.Pane.new(id: :pane, title: "Pane", lines: ["hello"])

    assert node.kind == :widget
    assert node.id == :pane
    assert node.module == Workbench.Widgets.Pane
    assert node.props.title == "Pane"
  end

  test "widget list constructor keeps variable-height item props intact" do
    item = Workbench.Node.text(:item, "trace card")

    node =
      Widgets.WidgetList.new(id: :trace, title: "Trace", items: [{item, 3}], scroll_offset: 2)

    assert node.module == Workbench.Widgets.WidgetList
    assert node.props.title == "Trace"
    assert node.props.scroll_offset == 2
    assert node.props.items == [{item, 3}]
  end

  test "widget constructors normalize shared style keys onto node style" do
    node =
      Widgets.List.new(
        id: :sites,
        title: "Sites",
        items: ["local", "demo"],
        border_fg: :accent,
        highlight_fg: :focus
      )

    assert node.style[:border_fg] == :accent
    assert node.style[:highlight_fg] == :focus
  end
end
