# `Switchyard.Contracts.Job`

Typed job contract.

# `t`

```elixir
@type t() :: %Switchyard.Contracts.Job{
  finished_at: DateTime.t() | nil,
  id: String.t(),
  kind: atom(),
  progress: %{current: non_neg_integer(), total: non_neg_integer()},
  related_resources: [term()],
  started_at: DateTime.t() | nil,
  status: atom(),
  title: String.t()
}
```

# `new!`

```elixir
@spec new!(map()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
