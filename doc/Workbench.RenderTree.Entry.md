# `Workbench.RenderTree.Entry`

Resolved render tree entry.

# `t`

```elixir
@type t() :: %Workbench.RenderTree.Entry{
  area: ExRatatui.Layout.Rect.t(),
  children: [t()],
  node: Workbench.Node.t(),
  path: [term()]
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
