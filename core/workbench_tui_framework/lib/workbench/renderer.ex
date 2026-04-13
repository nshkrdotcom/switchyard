defmodule Workbench.Renderer do
  @moduledoc "Renderer behaviour."

  @callback render(Workbench.RenderTree.t(), keyword()) ::
              [{ExRatatui.widget(), ExRatatui.Layout.Rect.t()}]
end

defmodule Workbench.Renderer.ExRatatui do
  @moduledoc "ExRatatui backend lowering for resolved render trees."

  @behaviour Workbench.Renderer

  alias ExRatatui.Style, as: ExStyle

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
  alias Workbench.Theme

  @impl true
  def render(%RenderTree{} = tree, opts \\ []) do
    tree.flat
    |> Enum.filter(fn entry -> entry.children == [] end)
    |> Enum.flat_map(&to_widget_tuple(&1, opts))
  end

  defp to_widget_tuple(%{node: %{kind: :component}}, _opts), do: []

  defp to_widget_tuple(%{node: %Node{kind: :text} = node, area: area}, opts) do
    [{text_widget(node, opts), area}]
  end

  defp to_widget_tuple(%{node: %Node{} = node, area: area}, opts) do
    [{widget_for(node, opts), area}]
  end

  defp widget_for(%Node{module: Workbench.Widgets.Pane} = node, opts), do: pane_widget(node, opts)

  defp widget_for(%Node{module: Workbench.Widgets.Detail} = node, opts),
    do: pane_widget(node, opts)

  defp widget_for(%Node{module: Workbench.Widgets.LogStream} = node, opts),
    do: pane_widget(node, opts)

  defp widget_for(%Node{module: Workbench.Widgets.StatusBar} = node, opts),
    do: status_widget(node, opts)

  defp widget_for(%Node{module: Workbench.Widgets.Help} = node, opts), do: pane_widget(node, opts)
  defp widget_for(%Node{module: Workbench.Widgets.List} = node, opts), do: list_widget(node, opts)

  defp widget_for(%Node{module: Workbench.Widgets.WidgetList} = node, opts),
    do: widget_list_widget(node, opts)

  defp widget_for(%Node{module: Workbench.Widgets.Table} = node, opts),
    do: table_widget(node, opts)

  defp widget_for(%Node{module: Workbench.Widgets.Spinner} = node, opts),
    do: spinner_widget(node, opts)

  defp widget_for(%Node{module: Workbench.Widgets.ProgressBar} = node, opts),
    do: progress_widget(node, opts)

  defp widget_for(%Node{module: Workbench.Widgets.Tabs} = node, opts), do: tabs_widget(node, opts)

  defp widget_for(%Node{module: Workbench.Widgets.Modal} = node, opts),
    do: modal_widget(node, opts)

  defp widget_for(%Node{module: Workbench.Widgets.TextInput} = node, opts),
    do: pane_widget(node, opts)

  defp widget_for(%Node{module: Workbench.Widgets.TextArea} = node, opts),
    do: pane_widget(node, opts)

  defp widget_for(%Node{module: Workbench.Widgets.Viewport} = node, opts),
    do: pane_widget(node, opts)

  defp widget_for(%Node{module: Workbench.Widgets.Paginator} = node, opts),
    do: status_widget(node, opts)

  defp widget_for(%Node{module: Workbench.Widgets.Timer} = node, opts),
    do: status_widget(node, opts)

  defp widget_for(%Node{module: Workbench.Widgets.Tree} = node, opts), do: pane_widget(node, opts)
  defp widget_for(%Node{module: Workbench.Widgets.Form} = node, opts), do: pane_widget(node, opts)

  defp widget_for(%Node{module: Workbench.Widgets.FieldGroup} = node, opts),
    do: pane_widget(node, opts)

  defp widget_for(%Node{module: Workbench.Widgets.CommandPalette} = node, opts),
    do: pane_widget(node, opts)

  defp widget_for(%Node{module: Workbench.Widgets.FilePicker} = node, opts),
    do: pane_widget(node, opts)

  defp widget_for(%Node{module: module} = node, opts) do
    pane_widget(%{node | props: Map.put(node.props, :title, inspect(module))}, opts)
  end

  defp text_widget(%Node{} = node, opts) do
    %Paragraph{
      text: Map.get(node.props, :text, ""),
      wrap: Map.get(node.props, :wrap, true),
      alignment: alignment_for(node),
      style: text_style_for(node, opts, %ExStyle{})
    }
  end

  defp pane_widget(%Node{} = node, opts) do
    lines = Map.get(node.props, :lines, []) |> Elixir.List.wrap() |> Enum.join("\n")

    %Paragraph{
      text: lines,
      wrap: Map.get(node.props, :wrap, true),
      alignment: alignment_for(node),
      style: text_style_for(node, opts, %ExStyle{fg: :white}),
      block: block_for(node, opts, border_fg: :cyan, padding: {1, 1, 0, 0})
    }
  end

  defp status_widget(%Node{} = node, opts) do
    %Paragraph{
      text:
        Map.get(
          node.props,
          :text,
          Enum.join(Elixir.List.wrap(Map.get(node.props, :lines, [])), "  ·  ")
        ),
      wrap: false,
      alignment: alignment_for(node),
      style: text_style_for(node, opts, %ExStyle{fg: :green})
    }
  end

  defp list_widget(%Node{} = node, opts) do
    %List{
      items: Enum.map(Elixir.List.wrap(Map.get(node.props, :items, [])), &to_string/1),
      selected: Map.get(node.props, :selected),
      style: text_style_for(node, opts, %ExStyle{fg: :white}),
      highlight_symbol: Map.get(node.props, :highlight_symbol, "> "),
      highlight_style: highlight_style_for(node, opts, %ExStyle{fg: :yellow, modifiers: [:bold]}),
      block: block_for(node, opts, border_fg: :yellow, padding: {1, 1, 0, 0})
    }
  end

  defp widget_list_widget(%Node{} = node, opts) do
    %WidgetList{
      items:
        node.props
        |> Map.get(:items, [])
        |> Elixir.List.wrap()
        |> Enum.map(&widget_list_item(&1, opts)),
      selected: Map.get(node.props, :selected),
      scroll_offset: Map.get(node.props, :scroll_offset, 0),
      highlight_style: highlight_style_for(node, opts, %ExStyle{fg: :yellow, modifiers: [:bold]}),
      style: text_style_for(node, opts, %ExStyle{fg: :white}),
      block: block_for(node, opts, border_fg: :yellow, padding: {1, 1, 0, 0})
    }
  end

  defp table_widget(%Node{} = node, opts) do
    %Table{
      rows:
        Enum.map(Elixir.List.wrap(Map.get(node.props, :rows, [])), fn row ->
          Enum.map(row, &to_string/1)
        end),
      header: Enum.map(Elixir.List.wrap(Map.get(node.props, :header, [])), &to_string/1),
      widths: Map.get(node.props, :widths, []),
      selected: Map.get(node.props, :selected),
      style: text_style_for(node, opts, %ExStyle{fg: :white}),
      highlight_style: highlight_style_for(node, opts, %ExStyle{fg: :yellow, modifiers: [:bold]}),
      highlight_symbol: Map.get(node.props, :highlight_symbol, "> "),
      block: block_for(node, opts, border_fg: :yellow)
    }
  end

  defp widget_list_item({%Node{} = node, height}, opts) when is_integer(height) and height >= 0 do
    {item_widget(node, opts), height}
  end

  defp widget_list_item({widget, height}, _opts) when is_integer(height) and height >= 0 do
    {widget, height}
  end

  defp item_widget(%Node{kind: :text} = node, opts), do: text_widget(node, opts)

  defp item_widget(%Node{} = node, opts) do
    widget_for(node, opts)
  end

  defp spinner_widget(%Node{} = node, opts) do
    %Throbber{
      label: Map.get(node.props, :label, ""),
      step: Map.get(node.props, :step, 0),
      block: block_for(node, opts)
    }
  end

  defp progress_widget(%Node{} = node, opts) do
    %Gauge{
      ratio: Map.get(node.props, :ratio, 0.0),
      label: Map.get(node.props, :label),
      style: text_style_for(node, opts, %ExStyle{}),
      gauge_style: text_style_for(node, opts, %ExStyle{}),
      block: block_for(node, opts)
    }
  end

  defp tabs_widget(%Node{} = node, _opts) do
    %Tabs{
      titles: Enum.map(Elixir.List.wrap(Map.get(node.props, :titles, [])), &to_string/1),
      selected: Map.get(node.props, :selected, 0)
    }
  end

  defp modal_widget(%Node{} = node, opts) do
    content =
      pane_widget(
        %{node | props: %{title: "", lines: Map.get(node.props, :lines, [])}},
        opts
      )

    %Popup{
      content: content,
      fixed_width: Map.get(node.props, :width, 72),
      fixed_height: Map.get(node.props, :height, 18),
      block: block_for(node, opts, border_fg: :yellow, padding: {0, 0, 0, 0})
    }
  end

  defp block_for(%Node{} = node, opts, defaults \\ []) do
    style = normalized_node_style(node)
    theme = Keyword.get(opts, :theme, %{})

    %Block{
      title: Map.get(node.props, :title, ""),
      borders: Map.get(node.props, :borders, [:all]),
      border_type: Map.get(style, :border_type, Map.get(node.props, :border_type, :rounded)),
      border_style: %ExStyle{
        fg:
          color_from(
            Map.get(style, :border_fg, Map.get(node.props, :border_fg)),
            theme,
            Keyword.get(defaults, :border_fg)
          ),
        bg: color_from(Map.get(style, :border_bg), theme, nil),
        modifiers:
          Map.get(style, :border_modifiers, Map.get(node.props, :border_modifiers, []))
          |> Elixir.List.wrap()
      },
      style: text_style_for(node, opts, %ExStyle{}),
      padding:
        Map.get(
          style,
          :padding,
          Map.get(node.props, :padding, Keyword.get(defaults, :padding, {0, 0, 0, 0}))
        )
    }
  end

  defp text_style_for(%Node{} = node, opts, %ExStyle{} = defaults) do
    style = normalized_node_style(node)
    theme = Keyword.get(opts, :theme, %{})
    legacy_style = legacy_style_from(node.props, defaults)

    %ExStyle{
      fg: color_from(Map.get(style, :fg), theme, legacy_style.fg),
      bg: color_from(Map.get(style, :bg), theme, legacy_style.bg),
      modifiers: Map.get(style, :modifiers, legacy_style.modifiers)
    }
  end

  defp highlight_style_for(%Node{} = node, opts, %ExStyle{} = defaults) do
    style = normalized_node_style(node)
    theme = Keyword.get(opts, :theme, %{})

    %ExStyle{
      fg:
        color_from(
          Map.get(style, :highlight_fg, Map.get(node.props, :highlight_fg)),
          theme,
          defaults.fg
        ),
      bg: color_from(Map.get(style, :highlight_bg), theme, defaults.bg),
      modifiers:
        Map.get(
          style,
          :highlight_modifiers,
          Map.get(node.props, :highlight_modifiers, defaults.modifiers)
        )
        |> Elixir.List.wrap()
    }
  end

  defp normalized_node_style(%Node{} = node), do: Workbench.Style.normalize(node.style)

  defp alignment_for(%Node{} = node) do
    node
    |> normalized_node_style()
    |> Map.get(:align, Map.get(node.props, :alignment, :left))
  end

  defp legacy_style_from(props, %ExStyle{} = defaults) do
    case Map.get(props, :style) do
      %ExStyle{} = style -> style
      _other -> defaults
    end
  end

  defp color_from(value, theme, fallback), do: Theme.resolve_color(value, theme, fallback)
end
