# `Switchyard.LogRuntime`

Pure helpers for bounded log retention and filtering.

# `append`

```elixir
@spec append(Switchyard.LogRuntime.Buffer.t(), Switchyard.Contracts.LogEvent.t()) ::
  Switchyard.LogRuntime.Buffer.t()
```

# `filter`

```elixir
@spec filter(
  Switchyard.LogRuntime.Buffer.t(),
  keyword()
) :: [Switchyard.Contracts.LogEvent.t()]
```

# `new_buffer`

```elixir
@spec new_buffer(pos_integer()) :: Switchyard.LogRuntime.Buffer.t()
```

# `recent`

```elixir
@spec recent(Switchyard.LogRuntime.Buffer.t()) :: [Switchyard.Contracts.LogEvent.t()]
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
