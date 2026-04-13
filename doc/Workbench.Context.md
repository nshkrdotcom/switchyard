# `Workbench.Context`

Explicit immutable runtime context passed to component callbacks.

# `t`

```elixir
@type t() :: %Workbench.Context{
  app_env: map(),
  capabilities: Workbench.Capabilities.t(),
  clock: (-&gt; DateTime.t()),
  devtools: map(),
  path: [term()],
  request_handler: nil | (term(), keyword() -&gt; term()),
  screen: Workbench.Screen.t(),
  theme: map()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
