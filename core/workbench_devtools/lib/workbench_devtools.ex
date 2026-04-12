defmodule WorkbenchDevtools do
  @moduledoc """
  Public entrypoint for optional Workbench inspection helpers.
  """
end

defmodule Workbench.Devtools.Inspector do
  @moduledoc "Builds inspectable runtime snapshots."

  @spec snapshot(keyword()) :: map()
  def snapshot(opts) do
    %{
      render_tree: Keyword.get(opts, :render_tree),
      focus_tree: Keyword.get(opts, :focus_tree),
      region_map: Keyword.get(opts, :region_map),
      commands: Keyword.get(opts, :commands, []),
      subscriptions: Keyword.get(opts, :subscriptions, [])
    }
  end
end

defmodule Workbench.Devtools.Overlay do
  @moduledoc "Overlay metadata for dev-mode displays."

  @spec title() :: String.t()
  def title, do: "Workbench Inspector"
end

defmodule Workbench.Devtools.RenderTree do
  @moduledoc false
  def from_snapshot(snapshot), do: Map.get(snapshot, :render_tree)
end

defmodule Workbench.Devtools.FocusTree do
  @moduledoc false
  def from_snapshot(snapshot), do: Map.get(snapshot, :focus_tree)
end

defmodule Workbench.Devtools.RegionMap do
  @moduledoc false
  def from_snapshot(snapshot), do: Map.get(snapshot, :region_map)
end

defmodule Workbench.Devtools.FocusTrace do
  @moduledoc false
  def entries(focus_tree), do: Map.get(focus_tree || %{}, :paths, [])
end

defmodule Workbench.Devtools.EventLog do
  @moduledoc false
  def append(entries, event), do: List.wrap(entries) ++ [event]
end

defmodule Workbench.Devtools.CommandTrace do
  @moduledoc false
  def summarize(commands), do: Enum.map(commands, &Map.get(&1, :kind, :unknown))
end

defmodule Workbench.Devtools.RenderStats do
  @moduledoc false
  def from_tree(%Workbench.RenderTree{flat: flat}), do: %{entry_count: length(flat)}
  def from_tree(_other), do: %{entry_count: 0}
end

defmodule Workbench.Devtools.FileWatcher do
  @moduledoc false
  def enabled?, do: Code.ensure_loaded?(FileSystem)
end

defmodule Workbench.Devtools.HotReload do
  @moduledoc false
  def status, do: :planned
end
