# `Switchyard.Contracts.Action`

Typed action contract.

# `t`

```elixir
@type t() :: %Switchyard.Contracts.Action{
  confirmation: atom(),
  id: String.t(),
  input_schema: map(),
  provider: module(),
  scope: term(),
  title: String.t()
}
```

# `new!`

```elixir
@spec new!(map()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
