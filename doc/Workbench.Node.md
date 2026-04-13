# `Workbench.Node`

Backend-neutral render node.

# `kind`

```elixir
@type kind() :: :layout | :text | :widget | :component | :chrome | :portal | :leaf
```

# `t`

```elixir
@type t() :: %Workbench.Node{
  children: [t()],
  id: term(),
  kind: kind(),
  layout: Workbench.Layout.t(),
  meta: map(),
  module: module() | nil,
  props: map(),
  style: Workbench.Style.t()
}
```

# `component`

```elixir
@spec component(term(), module(), map() | keyword(), keyword()) :: t()
```

# `hstack`

```elixir
@spec hstack(term(), [t()], keyword()) :: t()
```

# `new`

```elixir
@spec new(keyword()) :: t()
```

# `text`

```elixir
@spec text(term(), String.t(), keyword()) :: t()
```

# `vstack`

```elixir
@spec vstack(term(), [t()], keyword()) :: t()
```

# `widget`

```elixir
@spec widget(term(), module(), map() | keyword()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
