# Switchyard Daemon

`switchyard_daemon` is the local control-plane core for Switchyard.

## Responsibilities

- start and supervise the daemon server
- expose the daemon API used by headless clients and apps
- own local process, job, log, and snapshot state
- answer local transport requests through a stable seam

## Quick Start

This package is the daemon runtime, not the runnable release wrapper. The
fastest way to validate it is through the focused test suite:

```bash
cd core/workbench_daemon
mix deps.get
mix test
```

The runtime currently supports:

- listing sites and apps
- reading a local snapshot
- starting a managed process
- fetching captured logs
- persisting a daemon snapshot to local storage

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

Then validate the workspace:

```bash
cd ../..
mix ci
```

## Examples

- [test/switchyard/daemon_test.exs](test/switchyard/daemon_test.exs) shows the end-to-end in-process daemon flow, including process start, log capture, and persisted snapshot state.

## Related Reading

- [Workspace README](../../README.md)
- [Runtime Model](../../guides/runtime_model.md)
- [Testing And Delivery](../../guides/testing_and_delivery.md)
