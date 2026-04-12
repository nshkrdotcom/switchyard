# Workbench Widgets

`workbench_widgets` provides backend-neutral widget constructors built on the
Workbench node IR from `workbench_node_ir`.

## Responsibilities

- expose reusable widget modules as Workbench nodes
- keep widget construction product-agnostic
- give the product TUI and external integrations a shared widget vocabulary

## Current Surface

The package currently includes constructors for:

- pane, list, detail, status bar, help, and modal
- variable-height widget list for row-based scrolling surfaces
- log stream, table, tree, tabs, paginator, and viewport
- text input, text area, form, and field group
- spinner, timer, and progress bar
- command palette and file picker

The renderer lowering lives in `workbench_tui_framework`; this package only
defines the backend-neutral widget nodes and should not depend on the renderer
package just to compile.

`Workbench.Widgets.WidgetList` is the current escape hatch for examples and app
surfaces that need per-row widget heights while staying backend-neutral.

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
