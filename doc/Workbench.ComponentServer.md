# `Workbench.ComponentServer`

GenServer wrapper for supervised framework components.

# `runtime_opts`

```elixir
@type runtime_opts() :: %{
  commands: [Workbench.Cmd.t()],
  render?: boolean(),
  trace?: term()
}
```

# `t`

```elixir
@type t() :: %Workbench.ComponentServer{
  ctx: Workbench.Context.t(),
  module: module(),
  props: map(),
  runtime_opts: runtime_opts(),
  state: term()
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `handle_info`

```elixir
@spec handle_info(pid(), term(), Workbench.Context.t()) ::
  {:ok, t(), runtime_opts()}
  | {:stop, t()}
  | {:stop, t(), runtime_opts()}
  | :unhandled
```

# `snapshot`

```elixir
@spec snapshot(pid()) :: t()
```

# `start_link`

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
```

# `update`

```elixir
@spec update(pid(), term(), Workbench.Context.t()) ::
  {:ok, t(), runtime_opts()}
  | {:stop, t()}
  | {:stop, t(), runtime_opts()}
  | :unhandled
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
