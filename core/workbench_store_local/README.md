# Switchyard Local Store

`switchyard_store_local` provides local JSON persistence primitives for the
daemon.

## Responsibilities

- persist named snapshots to disk
- read persisted snapshots back
- enumerate stored snapshot keys
- read and write daemon manifests
- read and write versioned snapshots under a namespace
- append and read JSONL journals
- return explicit malformed snapshot and journal errors
- migrate schema-version 0 snapshots to the current schema

## Quick Start

Validate the package locally:

```bash
cd core/workbench_store_local
mix deps.get
mix test
```

The storage seam is intentionally small and filesystem-backed. It stores safe
daemon summaries as JSON, not raw runtime processes or secret material.

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

- [test/switchyard/store/local_test.exs](test/switchyard/store/local_test.exs) covers snapshot persistence, retrieval, key listing, manifest read/write, versioned snapshots, migration, journal append/read, and malformed snapshot errors.

## Related Reading

- [Workspace README](../../README.md)
- [Runtime Model](../../guides/runtime_model.md)
