# `Switchyard.Daemon`

Local control-plane daemon API.

# `child_spec`

```elixir
@spec child_spec(keyword()) :: Supervisor.child_spec()
```

# `list_apps`

```elixir
@spec list_apps(GenServer.server(), String.t()) :: [
  Switchyard.Contracts.AppDescriptor.t()
]
```

# `list_sites`

```elixir
@spec list_sites(GenServer.server()) :: [Switchyard.Contracts.SiteDescriptor.t()]
```

# `logs`

```elixir
@spec logs(GenServer.server(), String.t()) :: [Switchyard.Contracts.LogEvent.t()]
```

# `snapshot`

```elixir
@spec snapshot(GenServer.server()) :: map()
```

# `start_link`

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
```

# `start_process`

```elixir
@spec start_process(GenServer.server(), map()) ::
  {:ok, Switchyard.Contracts.ActionResult.t()} | {:error, term()}
```

# `stop_process`

```elixir
@spec stop_process(GenServer.server(), String.t()) ::
  {:ok, Switchyard.Contracts.ActionResult.t()} | {:error, term()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
