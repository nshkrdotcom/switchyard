# `Workbench.Keymap`

Structured keybinding helpers.

# `binding`

```elixir
@type binding() :: Workbench.Keymap.Binding.t()
```

# `binding`

```elixir
@spec binding(keyword()) :: binding()
```

# `key`

```elixir
@spec key(String.t(), [String.t()]) :: Workbench.Keymap.Binding.chord()
```

# `match_event`

```elixir
@spec match_event([binding()], ExRatatui.Event.Key.t()) :: term() | nil
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
