# `Switchyard.Contracts.SiteDescriptor`

Descriptor for an installed site.

# `t`

```elixir
@type t() :: %Switchyard.Contracts.SiteDescriptor{
  capabilities: [atom()],
  environment: String.t(),
  id: String.t(),
  kind: atom(),
  provider: module(),
  title: String.t()
}
```

# `new!`

```elixir
@spec new!(map()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
