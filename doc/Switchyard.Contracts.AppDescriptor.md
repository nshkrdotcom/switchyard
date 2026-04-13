# `Switchyard.Contracts.AppDescriptor`

Descriptor for an app mounted under a site.

# `t`

```elixir
@type t() :: %Switchyard.Contracts.AppDescriptor{
  id: String.t(),
  provider: module(),
  resource_kinds: [atom()],
  route_kind: atom(),
  site_id: String.t(),
  title: String.t(),
  tui_component: module() | nil
}
```

# `new!`

```elixir
@spec new!(map()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
