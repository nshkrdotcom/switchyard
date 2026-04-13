# `Workbench.Runtime`

Framework runtime helpers used by thin Workbench-backed terminal apps.

# `init`

```elixir
@spec init(
  module(),
  keyword()
) :: {:ok, Workbench.Runtime.State.t(), keyword()} | {:error, term()}
```

# `render`

```elixir
@spec render(Workbench.Runtime.State.t(), ExRatatui.Frame.t()) :: [
  {ExRatatui.widget(), ExRatatui.Layout.Rect.t()}
]
```

# `render_accessible`

```elixir
@spec render_accessible(Workbench.Runtime.State.t()) ::
  Workbench.Accessibility.Node.t()
  | [Workbench.Accessibility.Node.t()]
  | :unsupported
```

# `subscriptions`

```elixir
@spec subscriptions(Workbench.Runtime.State.t()) :: [ExRatatui.Subscription.t()]
```

# `update`

```elixir
@spec update(term(), Workbench.Runtime.State.t()) ::
  {:noreply, Workbench.Runtime.State.t(), keyword()}
  | {:noreply, Workbench.Runtime.State.t()}
  | {:stop, Workbench.Runtime.State.t()}
  | {:stop, Workbench.Runtime.State.t(), keyword()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
