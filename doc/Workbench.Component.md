# `Workbench.Component`

Component behaviour for framework-backed screens and widgets.

# `callback_opts`

```elixir
@type callback_opts() :: Workbench.Cmd.t() | [Workbench.Cmd.t()] | keyword() | map()
```

# `actions`
*optional* 

```elixir
@callback actions(state :: term(), props :: map(), ctx :: Workbench.Context.t()) :: [
  Workbench.Action.t()
]
```

# `handle_info`
*optional* 

```elixir
@callback handle_info(
  msg :: term(),
  state :: term(),
  props :: map(),
  ctx :: Workbench.Context.t()
) ::
  {:ok, state :: term(), opts :: callback_opts()}
  | {:stop, state :: term()}
  | {:stop, state :: term(), opts :: callback_opts()}
  | :unhandled
```

# `init`

```elixir
@callback init(props :: map(), ctx :: Workbench.Context.t()) ::
  {:ok, state :: term(), opts :: callback_opts()}
```

# `keymap`
*optional* 

```elixir
@callback keymap(state :: term(), props :: map(), ctx :: Workbench.Context.t()) :: [
  Workbench.Keymap.binding()
]
```

# `mode`
*optional* 

```elixir
@callback mode() :: :pure | :supervised
```

# `render`

```elixir
@callback render(state :: term(), props :: map(), ctx :: Workbench.Context.t()) ::
  Workbench.Node.t()
```

# `render_accessible`
*optional* 

```elixir
@callback render_accessible(state :: term(), props :: map(), ctx :: Workbench.Context.t()) ::
  Workbench.Accessibility.Node.t()
  | [Workbench.Accessibility.Node.t()]
  | :unsupported
```

# `subscriptions`
*optional* 

```elixir
@callback subscriptions(state :: term(), props :: map(), ctx :: Workbench.Context.t()) ::
  [
    Workbench.Subscription.t()
  ]
```

# `update`

```elixir
@callback update(
  msg :: term(),
  state :: term(),
  props :: map(),
  ctx :: Workbench.Context.t()
) ::
  {:ok, state :: term(), opts :: callback_opts()}
  | {:stop, state :: term()}
  | {:stop, state :: term(), opts :: callback_opts()}
  | :unhandled
```

# `mode`

```elixir
@spec mode(module()) :: :pure | :supervised
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
