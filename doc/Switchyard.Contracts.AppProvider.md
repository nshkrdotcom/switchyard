# `Switchyard.Contracts.AppProvider`

Behaviour for site-contributed apps.

# `app_definition`

```elixir
@callback app_definition() :: Switchyard.Contracts.AppDescriptor.t()
```

# `detail`

```elixir
@callback detail(Switchyard.Contracts.Resource.t(), map()) ::
  Switchyard.Contracts.ResourceDetail.t()
```

# `list`

```elixir
@callback list(map()) :: [Switchyard.Contracts.Resource.t()]
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
