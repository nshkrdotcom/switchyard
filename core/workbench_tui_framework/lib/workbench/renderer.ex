defmodule Workbench.Renderer do
  @moduledoc "Renderer behaviour."

  @callback render(Workbench.RenderTree.t(), keyword()) ::
              [{ExRatatui.widget(), ExRatatui.Layout.Rect.t()}]
end

defmodule Workbench.Renderer.ExRatatui do
  @moduledoc "ExRatatui backend lowering for resolved render trees."

  @behaviour Workbench.Renderer

  alias ExRatatui.Style

  alias ExRatatui.Widgets.{
    Block,
    Gauge,
    List,
    Paragraph,
    Popup,
    Table,
    Tabs,
    Throbber,
    WidgetList
  }

  alias Workbench.{Node, RenderTree}

  @impl true
  def render(%RenderTree{} = tree, _opts \\ []) do
    tree.flat
    |> Enum.filter(fn entry -> entry.children == [] end)
    |> Enum.flat_map(&to_widget_tuple/1)
  end

  defp to_widget_tuple(%{node: %{kind: :component}}), do: []

  defp to_widget_tuple(%{node: %{kind: :text, props: props}, area: area}) do
    [{%Paragraph{text: Map.get(props, :text, ""), wrap: Map.get(props, :wrap, true)}, area}]
  end

  defp to_widget_tuple(%{node: %{module: module, props: props}, area: area}) do
    [{widget_for(module, props), area}]
  end

  defp widget_for(Workbench.Widgets.Pane, props), do: pane_widget(props)
  defp widget_for(Workbench.Widgets.Detail, props), do: pane_widget(props)
  defp widget_for(Workbench.Widgets.LogStream, props), do: pane_widget(props)
  defp widget_for(Workbench.Widgets.StatusBar, props), do: status_widget(props)
  defp widget_for(Workbench.Widgets.Help, props), do: pane_widget(props)
  defp widget_for(Workbench.Widgets.List, props), do: list_widget(props)
  defp widget_for(Workbench.Widgets.WidgetList, props), do: widget_list_widget(props)
  defp widget_for(Workbench.Widgets.Table, props), do: table_widget(props)
  defp widget_for(Workbench.Widgets.Spinner, props), do: spinner_widget(props)
  defp widget_for(Workbench.Widgets.ProgressBar, props), do: progress_widget(props)
  defp widget_for(Workbench.Widgets.Tabs, props), do: tabs_widget(props)
  defp widget_for(Workbench.Widgets.Modal, props), do: modal_widget(props)
  defp widget_for(Workbench.Widgets.TextInput, props), do: pane_widget(props)
  defp widget_for(Workbench.Widgets.TextArea, props), do: pane_widget(props)
  defp widget_for(Workbench.Widgets.Viewport, props), do: pane_widget(props)
  defp widget_for(Workbench.Widgets.Paginator, props), do: status_widget(props)
  defp widget_for(Workbench.Widgets.Timer, props), do: status_widget(props)
  defp widget_for(Workbench.Widgets.Tree, props), do: pane_widget(props)
  defp widget_for(Workbench.Widgets.Form, props), do: pane_widget(props)
  defp widget_for(Workbench.Widgets.FieldGroup, props), do: pane_widget(props)
  defp widget_for(Workbench.Widgets.CommandPalette, props), do: pane_widget(props)
  defp widget_for(Workbench.Widgets.FilePicker, props), do: pane_widget(props)
  defp widget_for(module, props), do: pane_widget(Map.put(props, :title, inspect(module)))

  defp pane_widget(props) do
    lines = Map.get(props, :lines, []) |> Elixir.List.wrap() |> Enum.join("\n")

    %Paragraph{
      text: lines,
      wrap: Map.get(props, :wrap, true),
      style: Map.get(props, :style, %Style{fg: :white}),
      block: %Block{
        title: Map.get(props, :title, ""),
        borders: [:all],
        border_type: :rounded,
        border_style: %Style{fg: Map.get(props, :border_fg, :cyan)},
        padding: {1, 1, 0, 0}
      }
    }
  end

  defp status_widget(props) do
    %Paragraph{
      text:
        Map.get(props, :text, Enum.join(Elixir.List.wrap(Map.get(props, :lines, [])), "  ·  ")),
      wrap: false,
      style: Map.get(props, :style, %Style{fg: :green})
    }
  end

  defp list_widget(props) do
    %List{
      items: Enum.map(Elixir.List.wrap(Map.get(props, :items, [])), &to_string/1),
      selected: Map.get(props, :selected),
      highlight_symbol: Map.get(props, :highlight_symbol, "> "),
      highlight_style: %Style{fg: Map.get(props, :highlight_fg, :yellow), modifiers: [:bold]},
      block: %Block{
        title: Map.get(props, :title, ""),
        borders: [:all],
        border_type: :rounded,
        border_style: %Style{fg: Map.get(props, :border_fg, :yellow)},
        padding: {1, 1, 0, 0}
      }
    }
  end

  defp widget_list_widget(props) do
    %WidgetList{
      items:
        props
        |> Map.get(:items, [])
        |> Elixir.List.wrap()
        |> Enum.map(&widget_list_item/1),
      selected: Map.get(props, :selected),
      scroll_offset: Map.get(props, :scroll_offset, 0),
      highlight_style: %Style{
        fg: Map.get(props, :highlight_fg, :yellow),
        modifiers: Map.get(props, :highlight_modifiers, [:bold])
      },
      style: Map.get(props, :style, %Style{fg: :white}),
      block: %Block{
        title: Map.get(props, :title, ""),
        borders: [:all],
        border_type: :rounded,
        border_style: %Style{fg: Map.get(props, :border_fg, :yellow)},
        padding: {1, 1, 0, 0}
      }
    }
  end

  defp table_widget(props) do
    %Table{
      rows:
        Enum.map(Elixir.List.wrap(Map.get(props, :rows, [])), fn row ->
          Enum.map(row, &to_string/1)
        end),
      header: Enum.map(Elixir.List.wrap(Map.get(props, :header, [])), &to_string/1),
      widths: Map.get(props, :widths, []),
      selected: Map.get(props, :selected),
      highlight_symbol: Map.get(props, :highlight_symbol, "> "),
      block: %Block{
        title: Map.get(props, :title, ""),
        borders: [:all],
        border_type: :rounded,
        border_style: %Style{fg: Map.get(props, :border_fg, :yellow)}
      }
    }
  end

  defp widget_list_item({%Node{} = node, height}) when is_integer(height) and height >= 0 do
    {item_widget(node), height}
  end

  defp widget_list_item({widget, height}) when is_integer(height) and height >= 0 do
    {widget, height}
  end

  defp item_widget(%Node{kind: :text, props: props}) do
    %Paragraph{text: Map.get(props, :text, ""), wrap: Map.get(props, :wrap, true)}
  end

  defp item_widget(%Node{module: module, props: props}) do
    widget_for(module, props)
  end

  defp spinner_widget(props) do
    %Throbber{
      label: Map.get(props, :label, ""),
      step: Map.get(props, :step, 0),
      block: %Block{
        title: Map.get(props, :title, ""),
        borders: [:all],
        border_type: :rounded
      }
    }
  end

  defp progress_widget(props) do
    %Gauge{
      ratio: Map.get(props, :ratio, 0.0),
      label: Map.get(props, :label),
      block: %Block{
        title: Map.get(props, :title, ""),
        borders: [:all],
        border_type: :rounded
      }
    }
  end

  defp tabs_widget(props) do
    %Tabs{
      titles: Enum.map(Elixir.List.wrap(Map.get(props, :titles, [])), &to_string/1),
      selected: Map.get(props, :selected, 0)
    }
  end

  defp modal_widget(props) do
    content = pane_widget(%{title: "", lines: Map.get(props, :lines, [])})

    %Popup{
      content: content,
      fixed_width: Map.get(props, :width, 72),
      fixed_height: Map.get(props, :height, 18),
      block: %Block{
        title: Map.get(props, :title, ""),
        borders: [:all],
        border_type: :rounded,
        border_style: %Style{fg: Map.get(props, :border_fg, :yellow)}
      }
    }
  end
end
