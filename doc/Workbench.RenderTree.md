# `Workbench.RenderTree`

Resolved render tree derived from declarative nodes.

# `t`

```elixir
@type t() :: %Workbench.RenderTree{
  flat: [Workbench.RenderTree.Entry.t()],
  root: Workbench.RenderTree.Entry.t()
}
```

# `flatten`

```elixir
@spec flatten(t() | Workbench.RenderTree.Entry.t()) :: [
  Workbench.RenderTree.Entry.t()
]
```

# `resolve`

```elixir
@spec resolve(Workbench.Node.t(), ExRatatui.Layout.Rect.t(), [term()]) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
