# `Switchyard.Shell`

Pure shell state and reducer helpers for the terminal host.

# `event`

```elixir
@type event() ::
  {:open_route, atom()}
  | {:select_site, String.t()}
  | {:select_app, String.t()}
  | {:focus_pane, atom()}
  | {:toggle_drawer, :jobs | :logs}
  | {:open_overlay, atom()}
  | :close_overlay
  | {:notify, String.t()}
```

# `new`

```elixir
@spec new() :: Switchyard.Shell.State.t()
```

# `reduce`

```elixir
@spec reduce(Switchyard.Shell.State.t(), event()) :: Switchyard.Shell.State.t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
