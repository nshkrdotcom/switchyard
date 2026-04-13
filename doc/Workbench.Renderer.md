# `Workbench.Renderer`

Renderer behaviour.

# `render`

```elixir
@callback render(
  Workbench.RenderTree.t(),
  keyword()
) :: [{ExRatatui.widget(), ExRatatui.Layout.Rect.t()}]
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
