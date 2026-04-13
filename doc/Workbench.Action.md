# `Workbench.Action`

Framework action descriptor.

# `t`

```elixir
@type t() :: %Workbench.Action{
  id: term(),
  keywords: [String.t()],
  run: nil | (-&gt; term()),
  scope: term(),
  subtitle: String.t() | nil,
  title: String.t() | nil
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
