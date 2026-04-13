# `Switchyard.LogRuntime.Buffer`

Bounded in-memory log buffer.

# `t`

```elixir
@type t() :: %Switchyard.LogRuntime.Buffer{
  entries: [Switchyard.Contracts.LogEvent.t()],
  max_entries: pos_integer()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
