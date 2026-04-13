# `Workbench.Keymap.Binding`

Single keybinding descriptor.

# `chord`

```elixir
@type chord() :: %{code: String.t(), modifiers: [String.t()]}
```

# `t`

```elixir
@type t() :: %Workbench.Keymap.Binding{
  description: String.t() | nil,
  enabled?: boolean(),
  id: term(),
  keys: [chord()],
  message: term(),
  scope: atom()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
