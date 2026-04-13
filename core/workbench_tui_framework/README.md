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
  for supervised components, retains normalized runtime opts in its snapshot
  state, returns update and `handle_info/4` results synchronously, and safely
  ignores optional `handle_info/4` when a component does not implement it.
- `Workbench.Runtime` now owns mounted child component registry/supervisor state
  and routes mounted child updates and info by stable component path.
- `Workbench.RenderTree` now applies `Workbench.Layout.padding` before splitting
  child areas.
- `Workbench.Renderer.ExRatatui` lowers `Workbench.Widgets.WidgetList` into
  `ExRatatui.Widgets.WidgetList`, so row-based variable-height scrolling can be
  exercised through the backend-neutral node layer, and it now lowers
  normalized `Workbench.Node.style` plus active theme tokens instead of treating
  widget-specific props as the only styling surface.

## Authoring Pattern

The preferred authoring surface is now:

```elixir
Pane.new(id: :header, title: "Local", lines: ["steady"])
|> Workbench.Style.border_fg(:accent)

Node.vstack(:root, children)
|> Workbench.Layout.with_padding({1, 1, 0, 0})
```

Renderer-specific `%ExRatatui.Style{}` structs remain supported as a lowering
fallback, but they are no longer the preferred authoring API.

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
