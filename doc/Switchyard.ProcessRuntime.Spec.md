# `Switchyard.ProcessRuntime.Spec`

Specification for a managed process.

# `t`

```elixir
@type t() :: %Switchyard.ProcessRuntime.Spec{
  command: String.t(),
  cwd: String.t() | nil,
  env: %{optional(String.t()) =&gt; String.t()},
  id: String.t()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
