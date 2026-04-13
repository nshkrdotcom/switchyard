# `Switchyard.Contracts.ResourceDetail`

Structured detail payload for a resource.

# `section`

```elixir
@type section() :: %{title: String.t(), lines: [String.t()]}
```

# `t`

```elixir
@type t() :: %Switchyard.Contracts.ResourceDetail{
  recommended_actions: [String.t()],
  resource: Switchyard.Contracts.Resource.t(),
  sections: [section()]
}
```

# `new!`

```elixir
@spec new!(map()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
