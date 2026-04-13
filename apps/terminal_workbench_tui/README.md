# Switchyard TUI

`switchyard_tui` is the Switchyard product TUI application. It is intentionally
thin and runs on top of the reusable Workbench runtime.

## Responsibilities

- start the terminal-facing product application
- boot the Switchyard root component
- compose site catalog data into Switchyard-specific views
- keep product workflow state out of the generic framework packages

It must not re-own generic rendering, effect, focus, mouse, or widget
infrastructure.

## Current Shape

The primary pieces are:

- a thin `ExRatatui.App` bridge
- a product root component
- a product theme bootstrap that supplies semantic tokens to the runtime
- a product-local UI state module
- CLI and escript startup wiring

Custom integrations plug in through `Switchyard.Contracts.AppDescriptor` using
`tui_component`, not through a compatibility mount seam.

The root screens now emit normalized `Workbench.Node.style` data and
`Workbench.Layout.padding` instead of relying on renderer-flavored style props.

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
- hand off to framework-native app components for richer product-specific flows

With `--debug` enabled, the app now also:

- creates a durable session artifact bundle under `tmp/switchyard_debug/...`
- shows a debug rail by default
- lets you toggle that rail with `F12`

On active app routes, `Esc` now reliably returns to the app list even when the
current app is a mounted custom component.

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
- [test/switchyard/tui/controller_test.exs](test/switchyard/tui/controller_test.exs) is the best entry point for understanding root-component routing and custom app component flow.
- [test/full_featured_workbench_example_test.exs](test/full_featured_workbench_example_test.exs) proves the example’s local and distributed smoke paths.

## Related Reading

- [Workspace README](../../README.md)
- [Guide Index](../../guides/index.md)
- [Package Boundaries](../../guides/package_boundaries.md)
- [Runtime Model](../../guides/runtime_model.md)
