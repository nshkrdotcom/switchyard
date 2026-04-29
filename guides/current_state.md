# Current State

Switchyard has moved past repository setup. The current workspace already
proves the main platform seams and ships a coherent internal operator stack.

## Workspace Snapshot

- 20 Mix projects in one non-umbrella workspace
- 13 reusable `core/*` packages
- 3 site packages: `sites/site_execution_plane`, `sites/site_jido`, and
  `sites/site_local`
- 3 runnable apps: TUI, CLI, and daemon
- root workspace orchestration with Blitz and internal artifact shaping through
  Weld

## Delivered Platform Layers

### Contracts And Catalog

- `core/workbench_contracts` defines typed site, app, resource, action, job,
  and log vocabulary.
- `core/workbench_platform` turns configured site providers into a platform
  catalog.

### Local Control Plane

- `core/workbench_daemon` owns the daemon seam and local authority boundary.
- `core/workbench_transport_local` gives the CLI, tests, and in-process clients
  a UI-agnostic transport path.
- `core/workbench_process_runtime`, `core/workbench_job_runtime`,
  `core/workbench_log_runtime`, and `core/workbench_store_local` hold the
  runtime and persistence primitives under that daemon boundary.
- `core/workbench_store_local` now supports manifests, versioned snapshots,
  JSONL journals, explicit malformed snapshot errors, and schema migration.
- `core/workbench_process_runtime` now acts as the unified execution plane with
  explicit execution surfaces for local subprocesses and SSH exec plus honest
  sandbox policy handling.

### Shell And TUI Infrastructure

- `core/workbench_shell_core` keeps shell state pure and presentation-agnostic.
- `core/workbench_node_ir` provides the backend-neutral node and layout
  vocabulary.
- `core/workbench_widgets` provides reusable widget constructors on top of that
  node layer.
- `core/workbench_tui_framework` provides the component contract, runtime,
  effect/subscription handling, focus and region indexing, and renderer bridge
  to `ex_ratatui`.
- `core/workbench_devtools` holds optional inspection-oriented tooling for the
  runtime.

### Built-In Product Surfaces

- `sites/site_execution_plane` maps live runtime substrate state into process,
  operator-terminal, job, stream, and site-state resources.
- `sites/site_jido` maps durable Jido runs, boundary sessions, and attach
  grants into the same contract surface, including explicit site-state
  resources.
- `sites/site_local` remains in the repo as a focused local reference site.
- `apps/terminal_workbenchd` starts the daemon with the first-party site set.
- `apps/terminal_workbench_cli` exposes headless JSON inspection commands.
- `apps/terminal_workbench_tui` hosts the product shell on top of the reusable
  Workbench runtime.

## Current Operator Experience

The built-in Switchyard shell already supports:

- a home screen listing available sites
- per-site app selection
- generic list/detail screens for resource-backed apps
- daemon-backed snapshot refresh from the product shell
- a minimal process-start action on the Execution Plane processes app
- resource-scoped action listing, form defaults, confirmation, and result
  status in generic TUI detail views
- recent process log preview through the daemon log request path
- degraded recovery warnings after snapshot refresh
- custom framework-native app components through `AppDescriptor.tui_component`

The TUI can now be run in three operator-access modes:

- local terminal mode
- SSH-served mode through `ex_ratatui`
- distributed mode through `ex_ratatui`

The active first-party site catalog now splits live and durable truth
explicitly:

- `site_execution_plane` exposes processes, operator terminals, jobs, streams,
  search, and explicit site-state resources
- `site_jido` exposes runs, boundary sessions, and attach grants

Process details still surface command preview, execution surface, target, and
sandbox mode through the daemon snapshot seam. They now also carry typed
lifecycle status, status reason, exit status, lifecycle timestamps, related job
IDs, and related stream IDs.

The CLI currently supports:

- `switchyard_cli sites`
- `switchyard_cli apps <site-id>`
- `switchyard_cli actions [site-id]`
- `switchyard_cli actions --site <site-id>`
- `switchyard_cli action run <action-id> [--site <site-id>] [--resource kind:id]
  [--input-json JSON] [--confirm]`
- `switchyard_cli snapshot`
- `switchyard_cli recovery`
- `switchyard_cli process start ...`
- `switchyard_cli process list`
- `switchyard_cli process inspect <process-id>`
- `switchyard_cli process stop <process-id> --confirm`
- `switchyard_cli streams`
- `switchyard_cli logs <stream-id> --tail <n>`
- `switchyard_cli process logs <process-id> --after-seq <n>`
- `switchyard_cli process restart <process-id> --confirm` with explicit unsupported/retry
  guidance until restart support is backed by safe restart specs
- `switchyard_cli process signal <process-id> <signal>` with explicit
  unsupported guidance until transport support exists

## Packaging Posture

Switchyard is currently delivered as an internal workspace and internal Weld
projection, not as a Hex-first published product suite.

That posture is explicit:

- the Workbench runtime depends on `ex_ratatui` from Hex
- the current workspace tracks `ex_ratatui` `0.8.1`
- Weld projects the internal `switchyard_foundation` artifact
- `mix release.prepare` builds the prepared bundle,
  `mix release.track` updates `projection/switchyard_foundation`,
  and `mix release.archive` preserves the validated bundle
- `release.publish` remains out of scope

## What The Next Phase Should Mean

Future work should extend breadth and depth without re-litigating the existing
architecture:

- add richer command palette/text editing ergonomics over the existing generic
  TUI action flow
- add durable stream follow cursors and transport-proven reconnect only when
  lower surfaces can prove those semantics
- harden the current operator flows and release packaging posture
- keep the daemon, shell, framework, and site boundaries explicit
- keep adding execution surfaces and sandbox capabilities through the unified
  execution-plane seam instead of bypassing the daemon
