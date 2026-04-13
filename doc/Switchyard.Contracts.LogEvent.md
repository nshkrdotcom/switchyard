# `Switchyard.Contracts.LogEvent`

Normalized log event contract.

# `t`

```elixir
@type t() :: %Switchyard.Contracts.LogEvent{
  at: DateTime.t(),
  fields: map(),
  level: atom(),
  message: String.t(),
  source_id: String.t(),
  source_kind: atom(),
  stream_id: String.t()
}
```

# `new!`

```elixir
@spec new!(map()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
