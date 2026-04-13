# `Workbench.Accessibility.Node`

Accessible fallback interaction node.

# `t`

```elixir
@type t() :: %Workbench.Accessibility.Node{
  children: [t()],
  kind: atom(),
  label: String.t() | nil,
  meta: map(),
  value: String.t() | nil
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
