# `Switchyard.Contracts.SearchResult`

Typed search result contract.

# `t`

```elixir
@type t() :: %Switchyard.Contracts.SearchResult{
  action: term(),
  id: String.t(),
  kind: atom(),
  score: float(),
  subtitle: String.t() | nil,
  title: String.t()
}
```

# `new!`

```elixir
@spec new!(map()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
