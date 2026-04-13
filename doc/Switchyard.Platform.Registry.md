# `Switchyard.Platform.Registry`

Registry helpers for site provider modules.

# `actions`

```elixir
@spec actions(String.t(), [module()]) :: [Switchyard.Contracts.Action.t()]
```

# `apps`

```elixir
@spec apps(String.t(), [module()]) :: [Switchyard.Contracts.AppDescriptor.t()]
```

# `provider`

```elixir
@spec provider(String.t(), [module()]) :: module() | nil
```

# `site`

```elixir
@spec site(String.t(), [module()]) :: Switchyard.Contracts.SiteDescriptor.t() | nil
```

# `sites`

```elixir
@spec sites([module()]) :: [Switchyard.Contracts.SiteDescriptor.t()]
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
