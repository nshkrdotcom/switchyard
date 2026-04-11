# Switchyard Local Store

`switchyard_store_local` provides local JSON snapshot persistence for the
daemon.

## Responsibilities

- persist named snapshots to disk
- read persisted snapshots back
- enumerate stored snapshot keys

## Quick Start

Validate the package locally:

```bash
cd core/workbench_store_local
mix deps.get
mix test
```

The storage seam is intentionally simple: filesystem-backed JSON snapshots for
local daemon state.

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

For workspace-wide validation:

```bash
cd ../..
mix ci
```

## Examples

- [test/switchyard/store/local_test.exs](test/switchyard/store/local_test.exs) covers snapshot persistence, retrieval, and key listing behavior.

## Related Reading

- [Workspace README](../../README.md)
- [Runtime Model](../../guides/runtime_model.md)
