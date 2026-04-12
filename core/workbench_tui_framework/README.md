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
- `Workbench.Context`
- `Workbench.RenderTree`
- `Workbench.FocusTree`
- `Workbench.RegionMap`
- `Workbench.RuntimeIndex`
- `Workbench.Cmd`
- `Workbench.EffectRunner`
- `Workbench.Runtime`
- `Workbench.Renderer.ExRatatui`

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
