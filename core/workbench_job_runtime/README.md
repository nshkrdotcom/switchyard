# Switchyard Job Runtime

`switchyard_job_runtime` defines structured local job lifecycle behavior.

## Responsibilities

- create typed job records
- validate lifecycle transitions
- track progress counters
- keep job state consistent across daemon operations

## Quick Start

Validate the package locally:

```bash
cd core/workbench_job_runtime
mix deps.get
mix test
```

If you want to inspect the API in `iex`, start with `Switchyard.JobRuntime.new/1`
and `Switchyard.JobRuntime.transition/2`.

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

- [test/switchyard/job_runtime_test.exs](test/switchyard/job_runtime_test.exs) covers new jobs, lifecycle transitions, progress updates, and invalid transition rejection.

## Related Reading

- [Workspace README](../../README.md)
- [Runtime Model](../../guides/runtime_model.md)
