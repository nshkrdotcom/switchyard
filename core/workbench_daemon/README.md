# Switchyard Daemon

`switchyard_daemon` is the local control-plane core for Switchyard.

## Responsibilities

- start and supervise the daemon server
- expose the daemon API used by headless clients and apps
- own local process, job, log, and snapshot state
- preserve execution-surface and sandbox metadata for managed processes
- list and execute registered operator actions through the daemon request seam
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
- listing registered actions globally, by site, or by resource
- executing actions through `%{kind: :execute_action}` with scope, input, and
  confirmation validation
- reading a workspace snapshot
- starting and stopping managed processes through the generic action path
- tracking typed lifecycle state, status reasons, exit status, timestamps,
  related job IDs, and related stream IDs
- listing stream descriptors and reading filtered/tail log events with
  per-stream sequence numbers
- persisting a daemon snapshot to local storage

The snapshot now carries both live and durable operator state:

- live Execution Plane processes, operator terminals, jobs, process log streams,
  and job event streams
- durable Jido runs, boundary sessions, and attach grants

Managed-process snapshot records now include:

- typed lifecycle status and reason
- exit status and lifecycle timestamps
- command preview
- args
- shell and cwd metadata
- safe environment summary
- execution-surface summary
- sandbox summary
- related job IDs and stream IDs

Log events now include per-stream sequence numbers in `fields.seq`, process
output metadata such as `fields.fd`, and job event metadata for lifecycle jobs.

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

- [test/switchyard/daemon_test.exs](test/switchyard/daemon_test.exs) shows the end-to-end in-process daemon flow, including action listing/execution, process lifecycle state, execution metadata preservation, log capture, and persisted snapshot state.

## Related Reading

- [Workspace README](../../README.md)
- [Runtime Model](../../guides/runtime_model.md)
- [Testing And Delivery](../../guides/testing_and_delivery.md)
