defmodule Workbench.RenderTree.Entry do
  @moduledoc "Resolved render tree entry."

  defstruct path: [],
            area: nil,
            node: nil,
            children: []

  @type t :: %__MODULE__{
          path: [term()],
          area: ExRatatui.Layout.Rect.t(),
          node: Workbench.Node.t(),
          children: [t()]
        }
end

defmodule Workbench.RenderTree do
  @moduledoc "Resolved render tree derived from declarative nodes."

  alias ExRatatui.Layout
  alias ExRatatui.Layout.Rect
  alias Workbench.RenderTree.Entry

  defstruct root: nil, flat: []

  @type t :: %__MODULE__{root: Entry.t(), flat: [Entry.t()]}

  @spec resolve(Workbench.Node.t(), Rect.t(), [term()]) :: t()
  def resolve(node, %Rect{} = area, path \\ ["root"]) do
    root = resolve_entry(node, area, path)
    %__MODULE__{root: root, flat: flatten(root)}
  end

  @spec flatten(t() | Entry.t()) :: [Entry.t()]
  def flatten(%__MODULE__{root: root}), do: flatten(root)

  def flatten(%Entry{} = entry) do
    [entry | Enum.flat_map(entry.children, &flatten/1)]
  end

  defp resolve_entry(%Workbench.Node{} = node, %Rect{} = area, path) do
    child_area = inset_area(area, node.layout.padding)

    children =
      case {node.kind, node.layout.direction, node.children} do
        {:layout, :vertical, children} when is_list(children) ->
          split_children(children, child_area, :vertical, node.layout.constraints, path)

        {:layout, :horizontal, children} when is_list(children) ->
          split_children(children, child_area, :horizontal, node.layout.constraints, path)

        {:portal, _direction, children} when is_list(children) ->
          Enum.with_index(children, fn child, index ->
            child_path = path ++ [child.id || index]
            resolve_entry(child, child_area, child_path)
          end)

        _other ->
          []
      end

    %Entry{path: path, area: area, node: node, children: children}
  end

  defp split_children(children, area, direction, constraints, path) do
    rects = Layout.split(area, direction, normalize_constraints(children, constraints))

    children
    |> Enum.zip(rects)
    |> Enum.with_index()
    |> Enum.map(fn {{child, rect}, index} ->
      child_path = path ++ [child.id || index]
      resolve_entry(child, rect, child_path)
    end)
  end

  defp normalize_constraints(children, []), do: equal_constraints(children)
  defp normalize_constraints(_children, constraints), do: constraints

  defp equal_constraints([]), do: []

  defp equal_constraints(children) do
    percentage = floor(100 / max(length(children), 1))
    Enum.map(children, fn _ -> {:percentage, percentage} end)
  end

  defp inset_area(%Rect{} = area, {left, right, top, bottom}) do
    %Rect{
      x: area.x + left,
      y: area.y + top,
      width: max(area.width - left - right, 0),
      height: max(area.height - top - bottom, 0)
    }
  end
end

defmodule Workbench.FocusTree do
  @moduledoc "Derived focus traversal metadata."

  defstruct paths: []

  @type t :: %__MODULE__{paths: [[term()]]}

  @spec build(Workbench.RenderTree.t()) :: t()
  def build(%Workbench.RenderTree{} = tree) do
    paths =
      tree.flat
      |> Enum.filter(fn entry -> Map.get(entry.node.meta, :focusable, false) end)
      |> Enum.map(& &1.path)

    %__MODULE__{paths: paths}
  end
end

defmodule Workbench.RegionMap.Region do
  @moduledoc "Resolved mouse region."

  defstruct id: nil, path: [], area: nil, capture: :bubble

  @type t :: %__MODULE__{
          id: term(),
          path: [term()],
          area: ExRatatui.Layout.Rect.t(),
          capture: :bubble | :capture
        }
end

defmodule Workbench.RegionMap do
  @moduledoc "Derived mouse hit-test regions."

  alias Workbench.RegionMap.Region

  defstruct regions: []

  @type t :: %__MODULE__{regions: [Region.t()]}

  @spec build(Workbench.RenderTree.t()) :: t()
  def build(%Workbench.RenderTree{} = tree) do
    regions =
      tree.flat
      |> Enum.flat_map(fn entry ->
        case Map.get(entry.node.meta, :region) do
          nil ->
            []

          %{id: id, capture: capture} ->
            [%Region{id: id, path: entry.path, area: entry.area, capture: capture}]

          id ->
            [%Region{id: id, path: entry.path, area: entry.area, capture: :bubble}]
        end
      end)

    %__MODULE__{regions: regions}
  end
end

defmodule Workbench.RuntimeIndex do
  @moduledoc "Derived runtime indexes for bindings, actions, and subscriptions."

  defstruct keybindings: [], actions: [], subscriptions: []

  @type t :: %__MODULE__{
          keybindings: [Workbench.Keymap.binding()],
          actions: [Workbench.Action.t()],
          subscriptions: [Workbench.Subscription.t()]
        }
end
