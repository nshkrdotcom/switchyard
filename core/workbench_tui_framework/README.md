# Workbench TUI Framework

`workbench_tui_framework` is the reusable BEAM-native TUI runtime extracted from
the Switchyard product app.

## Responsibilities

- define the Workbench component contract
- carry explicit context, screen, capability, and effect primitives
- build the render tree and runtime indexes
- own keymap, action, focus, mouse, transcript, and subscription seams
- bridge framework commands and subscriptions onto `ex_ratatui`

This package must stay product-agnostic.

The backend-neutral node IR lives in `workbench_node_ir`; this package depends
on that package instead of owning `Workbench.Node` directly.

## Key Modules

- `Workbench.Component`
- `Workbench.ComponentServer`
- `Workbench.ComponentSupervisor`
- `Workbench.Context`
- `Workbench.RenderTree`
- `Workbench.FocusTree`
- `Workbench.RegionMap`
- `Workbench.RuntimeIndex`
- `Workbench.Cmd`
- `Workbench.EffectRunner`
- `Workbench.Runtime`
- `Workbench.Renderer.ExRatatui`

## Runtime Contract

- `Workbench.Component` callbacks can return a single command, a list of
  commands, or runtime opts with `commands`, `render?`, and `trace?`.
- `Workbench.ComponentServer` mirrors the same update and stop tuple contract
  for supervised components and safely ignores optional `handle_info/4` when a
  component does not implement it.
- `Workbench.Renderer.ExRatatui` lowers `Workbench.Widgets.WidgetList` into
  `ExRatatui.Widgets.WidgetList`, so row-based variable-height scrolling can be
  exercised through the backend-neutral node layer.

## Package Checks

From this directory:

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix credo --strict
mix dialyzer
mix docs --warnings-as-errors
```

For repo-wide validation:

```bash
cd ../..
mix ci
```
