# `Workbench.Subscription`

Framework subscription descriptors.

# `t`

```elixir
@type t() :: %Workbench.Subscription{
  generation: non_neg_integer(),
  id: term(),
  interval_ms: pos_integer(),
  kind: :interval | :once,
  message: term()
}
```

# `interval`

```elixir
@spec interval(term(), pos_integer(), term(), non_neg_integer()) :: t()
```

# `once`

```elixir
@spec once(term(), pos_integer(), term(), non_neg_integer()) :: t()
```

# `to_ex_ratatui`

```elixir
@spec to_ex_ratatui(t()) :: ExRatatui.Subscription.t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
