defmodule WorkbenchNodeIr do
  @moduledoc """
  Public entrypoint for the backend-neutral Workbench node IR package.
  """
end

defmodule Workbench.Layout do
  @moduledoc "Declarative layout intent for a node subtree."

  defstruct direction: nil, constraints: [], padding: {0, 0, 0, 0}

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
          padding: {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
        }
end

defmodule Workbench.Node do
  @moduledoc "Backend-neutral render node."

  alias Workbench.Layout

  defstruct id: nil,
            kind: :leaf,
            module: nil,
            props: %{},
            layout: %Layout{},
            style: [],
            children: [],
            meta: %{}

  @type kind :: :layout | :text | :widget | :component | :chrome | :portal | :leaf
  @type t :: %__MODULE__{
          id: term(),
          kind: kind(),
          module: module() | nil,
          props: map(),
          layout: Layout.t(),
          style: keyword(),
          children: [t()],
          meta: map()
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end

  @spec vstack(term(), [t()], keyword()) :: t()
  def vstack(id, children, opts \\ []) when is_list(children) do
    %__MODULE__{
      id: id,
      kind: :layout,
      children: children,
      layout: %Layout{direction: :vertical, constraints: Keyword.get(opts, :constraints, [])},
      meta: Map.new(Keyword.get(opts, :meta, []))
    }
  end

  @spec hstack(term(), [t()], keyword()) :: t()
  def hstack(id, children, opts \\ []) when is_list(children) do
    %__MODULE__{
      id: id,
      kind: :layout,
      children: children,
      layout: %Layout{direction: :horizontal, constraints: Keyword.get(opts, :constraints, [])},
      meta: Map.new(Keyword.get(opts, :meta, []))
    }
  end

  @spec text(term(), String.t(), keyword()) :: t()
  def text(id, value, opts \\ []) when is_binary(value) do
    %__MODULE__{
      id: id,
      kind: :text,
      props: %{text: value, wrap: Keyword.get(opts, :wrap, true)},
      meta: Map.new(Keyword.get(opts, :meta, []))
    }
  end

  @spec widget(term(), module(), map() | keyword()) :: t()
  def widget(id, widget_module, props) when is_atom(widget_module) do
    normalized_props = normalize_props(props)

    %__MODULE__{
      id: id,
      kind: :widget,
      module: widget_module,
      props: normalized_props,
      meta: normalize_props(Map.get(normalized_props, :meta, %{}))
    }
  end

  @spec component(term(), module(), map() | keyword(), keyword()) :: t()
  def component(id, component_module, props \\ %{}, opts \\ []) when is_atom(component_module) do
    normalized_props = normalize_props(props)

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
      meta: component_meta
    }
  end

  defp normalize_props(props) when is_map(props), do: props
  defp normalize_props(props) when is_list(props), do: Map.new(props)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
