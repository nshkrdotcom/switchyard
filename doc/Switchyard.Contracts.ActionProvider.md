# `Switchyard.Contracts.ActionProvider`

Behaviour for executable action providers.

# `action_definition`

```elixir
@callback action_definition() :: Switchyard.Contracts.Action.t()
```

# `execute`

```elixir
@callback execute(map(), map()) ::
  {:ok, Switchyard.Contracts.ActionResult.t()} | {:error, term()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
