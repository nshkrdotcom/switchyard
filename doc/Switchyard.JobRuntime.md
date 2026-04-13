# `Switchyard.JobRuntime`

Job contract helpers and state transitions.

# `new`

```elixir
@spec new(map()) :: Switchyard.Contracts.Job.t()
```

# `transition`

```elixir
@spec transition(Switchyard.Contracts.Job.t(), atom()) ::
  {:ok, Switchyard.Contracts.Job.t()} | {:error, :invalid_transition}
```

# `update_progress`

```elixir
@spec update_progress(
  Switchyard.Contracts.Job.t(),
  non_neg_integer(),
  non_neg_integer()
) ::
  Switchyard.Contracts.Job.t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
