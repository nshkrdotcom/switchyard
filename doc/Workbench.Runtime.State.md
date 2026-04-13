# `Workbench.Runtime.State`

Runtime state container for thin Workbench-backed terminal apps.

# `component_registry_entry`

```elixir
@type component_registry_entry() :: %{
  path: [term()],
  module: module(),
  mode: :pure | :supervised,
  props: map(),
  state: term(),
  pid: pid() | nil,
  runtime_opts: %{
    commands: [Workbench.Cmd.t()],
    render?: boolean(),
    trace?: term()
  }
}
```

Mounted-component registry entry shape stored in runtime state.

# `devtools_state`

```elixir
@type devtools_state() :: %{
  enabled?: boolean(),
  history_limit: pos_integer(),
  artifact_dir: String.t() | nil,
  session_label: String.t(),
  sink: (map() -&gt; term()) | nil,
  sequence: non_neg_integer(),
  events: [map()],
  commands: [map()],
  snapshots: [map()],
  latest: map() | nil
}
```

Runtime-owned debug configuration and bounded session history.

# `t`

```elixir
@type t() :: %Workbench.Runtime.State{
  app_env: map(),
  capabilities: Workbench.Capabilities.t(),
  component_registry: %{optional([term()]) =&gt; component_registry_entry()},
  component_supervisor: pid() | nil,
  devtools: devtools_state(),
  request_handler: (term(), keyword() -&gt; term()) | nil,
  root_module: module() | nil,
  root_props: map(),
  root_state: term(),
  screen_mode: :fullscreen | :inline | :mixed,
  theme: map(),
  transcript: Workbench.Transcript.t(),
  viewport: {non_neg_integer(), non_neg_integer()}
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
