# `Workbench.Devtools.Driver`

Deterministic reducer-runtime driver helpers for TUI automation.

This is the first automation layer. It intentionally drives the reducer
runtime through synthetic events and public snapshots instead of depending on
PTY scraping.

# `debug_snapshot`

```elixir
@spec debug_snapshot(GenServer.server(), timeout()) :: map()
```

# `inject_key`

```elixir
@spec inject_key(GenServer.server(), String.t(), [String.t()]) :: :ok
```

# `inject_resize`

```elixir
@spec inject_resize(GenServer.server(), non_neg_integer(), non_neg_integer()) :: :ok
```

# `snapshot`

```elixir
@spec snapshot(GenServer.server()) :: map()
```

# `wait_for_debug_snapshot!`

```elixir
@spec wait_for_debug_snapshot!(
  GenServer.server(),
  String.t(),
  (map() -&gt; as_boolean(term())),
  timeout()
) :: map()
```

# `wait_for_snapshot!`

```elixir
@spec wait_for_snapshot!(
  GenServer.server(),
  String.t(),
  (map() -&gt; as_boolean(term())),
  timeout()
) :: map()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
