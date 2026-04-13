# `Switchyard.Store.Local`

Filesystem-backed JSON persistence for local daemon state.

# `get_snapshot`

```elixir
@spec get_snapshot(Path.t(), String.t(), String.t()) :: {:ok, map()} | :error
```

# `list_keys`

```elixir
@spec list_keys(Path.t(), String.t()) :: [String.t()]
```

# `put_snapshot`

```elixir
@spec put_snapshot(Path.t(), String.t(), String.t(), map()) :: :ok
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
