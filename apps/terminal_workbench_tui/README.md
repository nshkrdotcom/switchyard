# Switchyard TUI

`switchyard_tui` is the terminal host application for Switchyard. It turns the
generic shell, daemon snapshot, and registered site apps into an operator-facing
terminal experience.

## Responsibilities

- start the terminal-facing application
- own generic shell layout and focus state
- render terminal view data over `ex_ratatui`
- host mounted site-specific workspaces without taking on their domain truth

## Quick Start

Build and run the escript from this package:

```bash
cd apps/terminal_workbench_tui
mix deps.get
mix escript.build
./switchyard --debug
```

The current startup path opens the generic home screen. From there you can:

- inspect registered sites
- open a site app
- use list/detail views for generic resource-backed apps
- host custom mounted apps through the `Switchyard.TUI.Mount` seam

## Developer Workflow

Run package-local checks from this directory:

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix credo --strict
mix dialyzer
mix docs --warnings-as-errors
```

For repo-wide validation, go back to the workspace root and run:

```bash
cd ../..
mix ci
```

## Examples

- [test/switchyard/tui_cli_test.exs](test/switchyard/tui_cli_test.exs) exercises the escript CLI surface.
- [test/switchyard/tui_test.exs](test/switchyard/tui_test.exs) covers the public `Switchyard.TUI` startup seam.
- [test/switchyard/tui/controller_test.exs](test/switchyard/tui/controller_test.exs) is the best entry point for understanding key handling and mounted app flow.

## Related Reading

- [Workspace README](../../README.md)
- [Guide Index](../../guides/index.md)
- [Package Boundaries](../../guides/package_boundaries.md)
- [Runtime Model](../../guides/runtime_model.md)
