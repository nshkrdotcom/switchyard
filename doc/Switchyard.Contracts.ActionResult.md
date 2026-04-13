# `Switchyard.Contracts.ActionResult`

Typed action execution result.

# `t`

```elixir
@type t() :: %Switchyard.Contracts.ActionResult{
  job_id: String.t() | nil,
  message: String.t(),
  output: term(),
  resource_ref: term() | nil,
  status: atom()
}
```

# `new!`

```elixir
@spec new!(map()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
