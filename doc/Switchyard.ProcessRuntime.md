# `Switchyard.ProcessRuntime`

Minimal managed local process runtime built on ports.

# `preview_command`

```elixir
@spec preview_command(Switchyard.ProcessRuntime.Spec.t()) :: String.t()
```

# `spec!`

```elixir
@spec spec!(map()) :: Switchyard.ProcessRuntime.Spec.t()
```

# `start_managed`

```elixir
@spec start_managed(Switchyard.ProcessRuntime.Spec.t(), pid()) :: GenServer.on_start()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
