# Switchyard Site Local

`switchyard_site_local` is the built-in local operations site for Switchyard.

## Responsibilities

- expose local apps such as processes, jobs, and logs
- map daemon snapshots into generic Switchyard resources
- expose recommended actions and resource details for local runtime state
- surface execution-surface and sandbox metadata for managed processes

## Quick Start

Validate the package locally:

```bash
cd sites/site_local
mix deps.get
mix test
```

The site currently maps:

- processes
- jobs

The logs app already exists in the catalog, and richer log-stream resource
mapping can grow on the same seam.

Process resources now summarize the command preview emitted by the daemon and
their detail view includes:

- command preview
- process status
- execution surface kind
- execution target
- sandbox mode

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

- [test/switchyard/site/local_test.exs](test/switchyard/site/local_test.exs) shows site/app descriptors, snapshot-to-resource mapping, and detail rendering with execution metadata.

## Related Reading

- [Workspace README](../../README.md)
- [Package Boundaries](../../guides/package_boundaries.md)
- [Runtime Model](../../guides/runtime_model.md)
