# Workbench Node IR

`workbench_node_ir` owns the backend-neutral node and layout vocabulary shared
by the Workbench framework and widget packages.

## Responsibilities

- define the declarative Workbench node tree
- carry layout intent without depending on a specific renderer package
- provide the stable IR that reusable widgets build on

This package is intentionally narrow. Runtime, effects, and renderer lowering
belong in `workbench_tui_framework`.

## Key Modules

- `Workbench.Layout`
- `Workbench.Node`

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
