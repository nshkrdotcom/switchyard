# `Switchyard.Contracts.SiteProvider`

Behaviour for installed site providers.

# `actions`

```elixir
@callback actions() :: [Switchyard.Contracts.Action.t()]
```

# `apps`

```elixir
@callback apps() :: [Switchyard.Contracts.AppDescriptor.t()]
```

# `detail`

```elixir
@callback detail(Switchyard.Contracts.Resource.t(), map()) ::
  Switchyard.Contracts.ResourceDetail.t()
```

# `resources`

```elixir
@callback resources(map()) :: [Switchyard.Contracts.Resource.t()]
```

# `site_definition`

```elixir
@callback site_definition() :: Switchyard.Contracts.SiteDescriptor.t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
