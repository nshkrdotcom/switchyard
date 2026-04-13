# `Switchyard.Contracts.StreamDescriptor`

Descriptor for a live stream.

# `t`

```elixir
@type t() :: %Switchyard.Contracts.StreamDescriptor{
  capabilities: [atom()],
  id: String.t(),
  kind: atom(),
  retention: atom(),
  subject: term()
}
```

# `new!`

```elixir
@spec new!(map()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
