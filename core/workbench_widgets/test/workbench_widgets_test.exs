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
end
