# Workbench Devtools

`workbench_devtools` holds optional inspection and development tooling for the
Workbench runtime.

## Responsibilities

- expose overlay-oriented inspection surfaces
- provide render-tree, focus-tree, and region-map views
- support event, command, and render-stat tracing
- host development helpers such as file watching and hot-reload plumbing

This package is intentionally optional. Product apps should be able to run
without it.

## Current Surface

- inspector and overlay helpers
- render-tree, focus-tree, and region-map inspection helpers
- focus, event, command, and render-stat tracing helpers
- file watching and hot-reload plumbing

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
