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
- log stream, table, tree, tabs, paginator, and viewport
- text input, text area, form, and field group
- spinner, timer, and progress bar
- command palette and file picker

The renderer lowering lives in `workbench_tui_framework`; this package only
defines the backend-neutral widget nodes and should not depend on the renderer
package just to compile.

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
