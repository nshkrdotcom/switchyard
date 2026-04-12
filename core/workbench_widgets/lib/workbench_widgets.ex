defmodule WorkbenchWidgets do
  @moduledoc """
  Public entrypoint for reusable Workbench widget constructors.
  """
end

defmodule Workbench.Widgets do
  @moduledoc false

  alias Workbench.Node

  def widget(module, opts) do
    id = Keyword.get(opts, :id, module)
    Node.widget(id, module, Map.new(opts))
  end
end

defmodule Workbench.Widgets.Pane do
  @moduledoc "Bordered content pane."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.List do
  @moduledoc "Selectable list widget."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.Detail do
  @moduledoc "Detail pane widget."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.StatusBar do
  @moduledoc "Single-line status widget."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.Modal do
  @moduledoc "Modal popup widget."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.LogStream do
  @moduledoc "Scrollable log stream widget."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.Help do
  @moduledoc "Generated help widget."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.TextInput do
  @moduledoc "Single-line text input widget."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.TextArea do
  @moduledoc "Multi-line text area widget."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.Viewport do
  @moduledoc "Scrollable viewport widget."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.Table do
  @moduledoc "Tabular data widget."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.Paginator do
  @moduledoc "Pagination status widget."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.Spinner do
  @moduledoc "Async activity indicator."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.Timer do
  @moduledoc "Timer display widget."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.ProgressBar do
  @moduledoc "Progress bar widget."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.Tabs do
  @moduledoc "Tabs widget."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.Tree do
  @moduledoc "Hierarchical tree widget."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.Form do
  @moduledoc "Form widget."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.FieldGroup do
  @moduledoc "Field grouping widget."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.CommandPalette do
  @moduledoc "Command palette widget."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end

defmodule Workbench.Widgets.FilePicker do
  @moduledoc "File picker widget."
  def new(opts), do: Workbench.Widgets.widget(__MODULE__, opts)
end
