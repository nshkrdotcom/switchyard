# `Switchyard.Shell.State`

Serializable shell state.

# `t`

```elixir
@type t() :: %Switchyard.Shell.State{
  drawers: %{jobs: boolean(), logs: boolean()},
  focused_pane: atom(),
  notifications: [String.t()],
  overlay: atom() | nil,
  route: atom(),
  selected_app_id: String.t() | nil,
  selected_site_id: String.t() | nil
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
