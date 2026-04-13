defmodule WorkbenchNodeIr do
  @moduledoc """
  Public entrypoint for the backend-neutral Workbench node IR package.
  """
end

defmodule Workbench.Layout do
  @moduledoc "Declarative layout intent for a node subtree."

  defstruct direction: nil, constraints: [], padding: {0, 0, 0, 0}

  @type padding ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
  @type direction :: :vertical | :horizontal | nil
  @type constraint ::
          {:percentage, non_neg_integer()}
          | {:length, non_neg_integer()}
          | {:min, non_neg_integer()}
          | {:max, non_neg_integer()}
          | {:ratio, non_neg_integer(), non_neg_integer()}
  @type t :: %__MODULE__{
          direction: direction(),
          constraints: [constraint()],
          padding: padding()
        }

  @spec with_padding(t(), padding() | [non_neg_integer()] | non_neg_integer()) :: t()
  def with_padding(%__MODULE__{} = layout, padding) do
    %{layout | padding: normalize_padding(padding)}
  end

  @spec with_padding(Workbench.Node.t(), padding() | [non_neg_integer()] | non_neg_integer()) ::
          Workbench.Node.t()
  def with_padding(%{__struct__: Workbench.Node} = node, padding) do
    %{node | layout: with_padding(node.layout || %__MODULE__{}, padding)}
  end

  @spec normalize_padding(padding() | [non_neg_integer()] | non_neg_integer() | nil) :: padding()
  def normalize_padding({left, right, top, bottom})
      when is_integer(left) and left >= 0 and is_integer(right) and right >= 0 and
             is_integer(top) and top >= 0 and is_integer(bottom) and bottom >= 0 do
    {left, right, top, bottom}
  end

  def normalize_padding([left, right, top, bottom]),
    do: normalize_padding({left, right, top, bottom})

  def normalize_padding(value) when is_integer(value) and value >= 0 do
    {value, value, value, value}
  end

  def normalize_padding(_other), do: {0, 0, 0, 0}
end

defmodule Workbench.Theme do
  @moduledoc "Theme token helpers for renderer-neutral Workbench styling."

  @tokens [:accent, :muted, :success, :warning, :danger, :surface, :surface_alt, :focus]

  @direct_colors [
    :black,
    :red,
    :green,
    :yellow,
    :blue,
    :magenta,
    :cyan,
    :gray,
    :dark_gray,
    :light_red,
    :light_green,
    :light_yellow,
    :light_blue,
    :light_magenta,
    :light_cyan,
    :white,
    :reset
  ]

  @spec tokens() :: [atom()]
  def tokens, do: @tokens

  @spec normalize(map() | keyword() | nil) :: map()
  def normalize(nil), do: %{}
  def normalize(theme) when is_list(theme), do: theme |> Map.new() |> normalize()
  def normalize(theme) when is_map(theme), do: Map.new(theme)

  @spec merge(map() | keyword() | nil, map() | keyword() | nil) :: map()
  def merge(base, overrides) do
    Map.merge(normalize(base), normalize(overrides))
  end

  @spec resolve_color(term(), map() | keyword() | nil, term()) :: term()
  def resolve_color(nil, _theme, fallback), do: fallback

  def resolve_color({:rgb, red, green, blue} = color, _theme, _fallback)
      when red in 0..255 and green in 0..255 and blue in 0..255,
      do: color

  def resolve_color({:indexed, value} = color, _theme, _fallback) when value in 0..255,
    do: color

  def resolve_color(color, _theme, _fallback) when color in @direct_colors, do: color

  def resolve_color(token, theme, fallback) when is_atom(token) do
    Map.get(normalize(theme), token, fallback)
  end

  def resolve_color(_other, _theme, fallback), do: fallback
end

defmodule Workbench.Style do
  @moduledoc "Renderer-neutral node style helpers."

  @keys [
    :fg,
    :bg,
    :modifiers,
    :align,
    :border_fg,
    :border_bg,
    :border_modifiers,
    :border_type,
    :padding,
    :highlight_fg,
    :highlight_bg,
    :highlight_modifiers,
    :weight,
    :variant
  ]

  @type t :: map()

  @spec keys() :: [atom()]
  def keys, do: @keys

  @spec normalize(map() | keyword() | nil) :: t()
  def normalize(nil), do: %{}
  def normalize(style) when is_list(style), do: style |> Map.new() |> normalize()

  def normalize(style) when is_map(style) do
    style
    |> Map.new()
    |> Map.take(@keys)
    |> normalize_weight()
    |> normalize_padding_key()
    |> normalize_modifier_key(:modifiers)
    |> normalize_modifier_key(:highlight_modifiers)
    |> normalize_modifier_key(:border_modifiers)
  end

  def merge(%{__struct__: Workbench.Node} = node, style) do
    %{node | style: Map.merge(normalize(node.style), normalize(style))}
  end

  def put(%{__struct__: Workbench.Node} = node, key, value), do: merge(node, %{key => value})

  def fg(%{__struct__: Workbench.Node} = node, value), do: put(node, :fg, value)
  def bg(%{__struct__: Workbench.Node} = node, value), do: put(node, :bg, value)
  def border_fg(%{__struct__: Workbench.Node} = node, value), do: put(node, :border_fg, value)
  def border_type(%{__struct__: Workbench.Node} = node, value), do: put(node, :border_type, value)
  def padding(%{__struct__: Workbench.Node} = node, value), do: put(node, :padding, value)
  def align(%{__struct__: Workbench.Node} = node, value), do: put(node, :align, value)

  def highlight_fg(%{__struct__: Workbench.Node} = node, value),
    do: put(node, :highlight_fg, value)

  def highlight_modifiers(%{__struct__: Workbench.Node} = node, value),
    do: put(node, :highlight_modifiers, value)

  def weight(%{__struct__: Workbench.Node} = node, value), do: put(node, :weight, value)

  @spec extract(map() | keyword() | nil) :: {t(), map() | keyword()}
  def extract(nil), do: {%{}, %{}}

  def extract(props) when is_list(props) do
    {style_entries, rest_entries} = Keyword.split(props, @keys)

    {style_override, rest_entries} =
      case Keyword.fetch(rest_entries, :style) do
        {:ok, nested_style} when is_list(nested_style) ->
          {nested_style, Keyword.delete(rest_entries, :style)}

        {:ok, nested_style} when is_map(nested_style) and not is_struct(nested_style) ->
          {nested_style, Keyword.delete(rest_entries, :style)}

        _other ->
          {%{}, rest_entries}
      end

    {normalize(style_entries) |> Map.merge(normalize(style_override)), rest_entries}
  end

  def extract(props) when is_map(props) do
    {style_entries, rest_entries} = Map.split(props, @keys)

    {style_override, rest_entries} =
      case Map.fetch(rest_entries, :style) do
        {:ok, nested_style} when is_list(nested_style) ->
          {nested_style, Map.delete(rest_entries, :style)}

        {:ok, nested_style} when is_map(nested_style) and not is_struct(nested_style) ->
          {nested_style, Map.delete(rest_entries, :style)}

        _other ->
          {%{}, rest_entries}
      end

    {normalize(style_entries) |> Map.merge(normalize(style_override)), rest_entries}
  end

  defp normalize_weight(%{weight: :bold} = style) do
    style
    |> Map.delete(:weight)
    |> Map.update(:modifiers, [:bold], fn modifiers -> List.wrap(modifiers) ++ [:bold] end)
  end

  defp normalize_weight(style), do: Map.delete(style, :weight)

  defp normalize_padding_key(%{padding: value} = style) do
    %{style | padding: Workbench.Layout.normalize_padding(value)}
  end

  defp normalize_padding_key(style), do: style

  defp normalize_modifier_key(style, key) do
    case Map.fetch(style, key) do
      {:ok, modifiers} -> Map.put(style, key, List.wrap(modifiers))
      :error -> style
    end
  end
end

defmodule Workbench.Node do
  @moduledoc "Backend-neutral render node."

  alias Workbench.Layout

  defstruct id: nil,
            kind: :leaf,
            module: nil,
            props: %{},
            layout: %Layout{},
            style: %{},
            children: [],
            meta: %{}

  @type kind :: :layout | :text | :widget | :component | :chrome | :portal | :leaf
  @type t :: %__MODULE__{
          id: term(),
          kind: kind(),
          module: module() | nil,
          props: map(),
          layout: Layout.t(),
          style: Workbench.Style.t(),
          children: [t()],
          meta: map()
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    style = Keyword.get(opts, :style, %{}) |> Workbench.Style.normalize()
    struct(__MODULE__, Keyword.put(opts, :style, style))
  end

  @spec vstack(term(), [t()], keyword()) :: t()
  def vstack(id, children, opts \\ []) when is_list(children) do
    %__MODULE__{
      id: id,
      kind: :layout,
      children: children,
      layout: %Layout{
        direction: :vertical,
        constraints: Keyword.get(opts, :constraints, []),
        padding: Layout.normalize_padding(Keyword.get(opts, :padding))
      },
      style: Keyword.get(opts, :style, %{}) |> Workbench.Style.normalize(),
      meta: Map.new(Keyword.get(opts, :meta, []))
    }
  end

  @spec hstack(term(), [t()], keyword()) :: t()
  def hstack(id, children, opts \\ []) when is_list(children) do
    %__MODULE__{
      id: id,
      kind: :layout,
      children: children,
      layout: %Layout{
        direction: :horizontal,
        constraints: Keyword.get(opts, :constraints, []),
        padding: Layout.normalize_padding(Keyword.get(opts, :padding))
      },
      style: Keyword.get(opts, :style, %{}) |> Workbench.Style.normalize(),
      meta: Map.new(Keyword.get(opts, :meta, []))
    }
  end

  @spec text(term(), String.t(), keyword()) :: t()
  def text(id, value, opts \\ []) when is_binary(value) do
    %__MODULE__{
      id: id,
      kind: :text,
      props: %{text: value, wrap: Keyword.get(opts, :wrap, true)},
      style: Keyword.get(opts, :style, %{}) |> Workbench.Style.normalize(),
      meta: Map.new(Keyword.get(opts, :meta, []))
    }
  end

  @spec widget(term(), module(), map() | keyword()) :: t()
  def widget(id, widget_module, props) when is_atom(widget_module) do
    {style, normalized_props} =
      props
      |> normalize_props()
      |> Workbench.Style.extract()

    normalized_props = normalize_props(normalized_props)

    %__MODULE__{
      id: id,
      kind: :widget,
      module: widget_module,
      props: normalized_props,
      style: style,
      meta: normalize_props(Map.get(normalized_props, :meta, %{}))
    }
  end

  @spec component(term(), module(), map() | keyword(), keyword()) :: t()
  def component(id, component_module, props \\ %{}, opts \\ []) when is_atom(component_module) do
    {style, normalized_props} =
      props
      |> normalize_props()
      |> Workbench.Style.extract()

    normalized_props = normalize_props(normalized_props)

    component_meta =
      opts
      |> Keyword.get(:meta, [])
      |> normalize_props()
      |> maybe_put(:component_mode, Keyword.get(opts, :mode))

    %__MODULE__{
      id: id,
      kind: :component,
      module: component_module,
      props: normalized_props,
      style: style,
      meta: component_meta
    }
  end

  @spec normalize_props(map() | keyword()) :: map()
  defp normalize_props(props) when is_map(props), do: props
  defp normalize_props(props) when is_list(props), do: Map.new(props)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
