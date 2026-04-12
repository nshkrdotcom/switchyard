defmodule Workbench.Screen do
  @moduledoc "Runtime screen configuration and viewport metadata."

  @enforce_keys [:mode]
  defstruct mode: :fullscreen, width: 0, height: 0

  @type mode :: :inline | :fullscreen | :mixed | :accessible
  @type t :: %__MODULE__{mode: mode(), width: non_neg_integer(), height: non_neg_integer()}
end

defmodule Workbench.Capabilities do
  @moduledoc "Negotiated terminal capability flags."

  defstruct mouse?: true,
            clipboard?: false,
            focus_reporting?: false,
            keyboard_enhanced?: true,
            color_profile: :truecolor

  @type t :: %__MODULE__{
          mouse?: boolean(),
          clipboard?: boolean(),
          focus_reporting?: boolean(),
          keyboard_enhanced?: boolean(),
          color_profile: atom()
        }
end

defmodule Workbench.Context do
  @moduledoc "Explicit immutable runtime context passed to component callbacks."

  defstruct theme: %{},
            screen: %Workbench.Screen{mode: :fullscreen},
            capabilities: %Workbench.Capabilities{},
            path: ["root"],
            request_handler: nil,
            devtools: %{},
            app_env: %{},
            clock: &DateTime.utc_now/0

  @type t :: %__MODULE__{
          theme: map(),
          screen: Workbench.Screen.t(),
          capabilities: Workbench.Capabilities.t(),
          path: [term()],
          request_handler: nil | (term(), keyword() -> term()),
          devtools: map(),
          app_env: map(),
          clock: (-> DateTime.t())
        }
end

defmodule Workbench.Layout do
  @moduledoc "Declarative layout intent for a node subtree."

  defstruct direction: nil, constraints: [], padding: {0, 0, 0, 0}

  @type direction :: :vertical | :horizontal | nil
  @type t :: %__MODULE__{
          direction: direction(),
          constraints: [ExRatatui.Layout.constraint()],
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

  @type kind :: :layout | :text | :widget | :chrome | :portal | :leaf
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
    %__MODULE__{
      id: id,
      kind: :widget,
      module: widget_module,
      props: normalize_props(props),
      meta: normalize_props(Map.get(normalize_props(props), :meta, %{}))
    }
  end

  defp normalize_props(props) when is_map(props), do: props
  defp normalize_props(props) when is_list(props), do: Map.new(props)
end

defmodule Workbench.Keymap.Binding do
  @moduledoc "Single keybinding descriptor."

  defstruct id: nil,
            keys: [],
            description: nil,
            message: nil,
            scope: :local,
            enabled?: true

  @type chord :: %{code: String.t(), modifiers: [String.t()]}
  @type t :: %__MODULE__{
          id: term(),
          keys: [chord()],
          description: String.t() | nil,
          message: term(),
          scope: atom(),
          enabled?: boolean()
        }
end

defmodule Workbench.Keymap do
  @moduledoc "Structured keybinding helpers."

  alias ExRatatui.Event
  alias Workbench.Keymap.Binding

  @type binding :: Binding.t()

  @spec binding(keyword()) :: binding()
  def binding(opts) do
    %Binding{
      id: Keyword.get(opts, :id),
      keys: List.wrap(Keyword.get(opts, :keys, [])),
      description: Keyword.get(opts, :description),
      message: Keyword.get(opts, :message),
      scope: Keyword.get(opts, :scope, :local),
      enabled?: Keyword.get(opts, :enabled?, true)
    }
  end

  @spec key(String.t(), [String.t()]) :: Binding.chord()
  def key(code, modifiers \\ []) when is_binary(code) and is_list(modifiers) do
    %{code: code, modifiers: Enum.sort(modifiers)}
  end

  @spec match_event([binding()], Event.Key.t()) :: term() | nil
  def match_event(bindings, %Event.Key{code: code, modifiers: modifiers}) do
    target = key(code, modifiers)

    Enum.find_value(bindings, fn
      %Binding{enabled?: true, keys: keys, message: message} ->
        if Enum.any?(keys, &(&1 == target)), do: message

      _other ->
        nil
    end)
  end
end

defmodule Workbench.Action do
  @moduledoc "Framework action descriptor."

  defstruct id: nil, title: nil, subtitle: nil, keywords: [], scope: :local, run: nil

  @type t :: %__MODULE__{
          id: term(),
          title: String.t() | nil,
          subtitle: String.t() | nil,
          keywords: [String.t()],
          scope: term(),
          run: nil | (-> term())
        }
end

defmodule Workbench.ActionRegistry do
  @moduledoc "Helpers for deriving active actions."

  alias Workbench.Action

  @spec build([Action.t()], [Action.t()]) :: [Action.t()]
  def build(global_actions, scoped_actions) do
    (List.wrap(global_actions) ++ List.wrap(scoped_actions))
    |> Enum.uniq_by(& &1.id)
  end
end

defmodule Workbench.FocusManager do
  @moduledoc "Focus path helpers."

  defstruct active_path: ["root"]

  @type t :: %__MODULE__{active_path: [term()]}
end

defmodule Workbench.Mouse do
  @moduledoc "Mouse region metadata helpers."

  @spec region(term(), keyword()) :: map()
  def region(id, opts \\ []) do
    %{id: id, capture: Keyword.get(opts, :capture, :bubble)}
  end
end

defmodule Workbench.Transcript do
  @moduledoc "Transcript lines for inline and mixed screen modes."

  defstruct lines: []

  @type t :: %__MODULE__{lines: [String.t()]}

  @spec append(t(), String.t()) :: t()
  def append(%__MODULE__{} = transcript, line) when is_binary(line) do
    %{transcript | lines: transcript.lines ++ [line]}
  end
end

defmodule Workbench.Accessibility.Node do
  @moduledoc "Accessible fallback interaction node."

  defstruct kind: :group, label: nil, value: nil, children: [], meta: %{}

  @type t :: %__MODULE__{
          kind: atom(),
          label: String.t() | nil,
          value: String.t() | nil,
          children: [t()],
          meta: map()
        }
end

defmodule Workbench.Accessibility do
  @moduledoc "Accessible mode helpers."

  @spec supported_output(term()) :: boolean()
  def supported_output(:unsupported), do: false
  def supported_output(_other), do: true
end
