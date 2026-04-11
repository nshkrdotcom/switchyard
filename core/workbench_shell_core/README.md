# Switchyard Shell Core

`switchyard_shell` holds pure shell state for the terminal workbench.

## Responsibilities

- route and selected-site state
- focused pane state
- drawer visibility
- notifications

## Quick Start

This package is a pure reducer/state layer. Validate it locally with:

```bash
cd core/workbench_shell_core
mix deps.get
mix test
```

Its purpose is to keep global shell behavior reducible and presentation-agnostic.
Terminal rendering belongs above this layer, not inside it.

## Developer Workflow

Run package-local checks:

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix credo --strict
mix dialyzer
mix docs --warnings-as-errors
```

For workspace validation:

```bash
cd ../..
mix ci
```

## Examples

- [test/switchyard/shell_test.exs](test/switchyard/shell_test.exs) shows route changes, site/app selection, pane focus, drawer toggles, overlays, and notifications.

## Related Reading

- [Workspace README](../../README.md)
- [Package Boundaries](../../guides/package_boundaries.md)
