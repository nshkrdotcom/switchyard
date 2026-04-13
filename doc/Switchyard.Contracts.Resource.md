# `Switchyard.Contracts.Resource`

Typed resource envelope used by shell and CLI surfaces.

# `t`

```elixir
@type t() :: %Switchyard.Contracts.Resource{
  capabilities: [atom()],
  ext: map(),
  id: String.t(),
  kind: atom(),
  site_id: String.t(),
  status: atom(),
  subtitle: String.t() | nil,
  summary: String.t() | nil,
  tags: [atom()],
  title: String.t()
}
```

# `new!`

```elixir
@spec new!(map()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
