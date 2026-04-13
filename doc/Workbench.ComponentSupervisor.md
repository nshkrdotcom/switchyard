# `Workbench.ComponentSupervisor`

Dynamic supervisor for supervised component processes.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `start_component`

```elixir
@spec start_component(
  pid(),
  keyword()
) :: DynamicSupervisor.on_start_child()
```

# `start_link`

```elixir
@spec start_link(keyword()) :: Supervisor.on_start()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
