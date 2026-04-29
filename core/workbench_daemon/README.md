# Switchyard Daemon

`switchyard_daemon` is the local control-plane core for Switchyard.

## Responsibilities

- start and supervise the daemon server
- expose the daemon API used by headless clients and apps
- own local process, job, log, and snapshot state
- preserve execution-surface and sandbox metadata for managed processes
- list and execute registered operator actions through the daemon request seam
- answer local transport requests through a stable seam
- persist safe local snapshots and recover audit state after daemon restart

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
- persisting daemon manifests, versioned snapshots, and recovery summaries to
  local storage
- replaying recovery journals and marking non-reconnectable running process
  records as `:lost` after daemon restart

The snapshot now carries both live and durable operator state:

- live Execution Plane processes, operator terminals, jobs, process log streams,
  and job event streams
- durable Jido runs, boundary sessions, and attach grants
- recovery status for memory-only, initialized, recovered, or degraded daemon
  state

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

Recovery is intentionally conservative. If a daemon restarts and no
transport-specific reconnect path proves that a running process is still
attached, the recovered process record becomes `:lost` with
`:daemon_restarted_without_reconnect`. Terminal process records remain terminal.

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

- [test/switchyard/daemon_test.exs](test/switchyard/daemon_test.exs) shows the end-to-end in-process daemon flow, including action listing/execution, process lifecycle state, execution metadata preservation, log capture, persisted snapshot state, and recovery behavior.
- [../../examples/repo_copy_tests/current_daemon_smoke_test.exs](../../examples/repo_copy_tests/current_daemon_smoke_test.exs) is a focused public-seam daemon smoke example.

## Related Reading

- [Workspace README](../../README.md)
- [Runtime Model](../../guides/runtime_model.md)
- [Testing And Delivery](../../guides/testing_and_delivery.md)
