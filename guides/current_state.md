# Current State

Switchyard has moved past repository setup. The current workspace already
proves the main platform seams and ships a coherent internal operator stack.

## Workspace Snapshot

- 18 Mix projects in one non-umbrella workspace
- 13 reusable `core/*` packages
- 1 built-in site package: `sites/site_local`
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
  `core/workbench_log_runtime`, and `core/workbench_store_local` hold the local
  runtime primitives under that daemon boundary.

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

- `sites/site_local` maps local runtime state into generic Switchyard apps,
  resources, and details.
- `apps/terminal_workbenchd` starts the daemon with the first-party site set.
- `apps/terminal_workbench_cli` exposes headless JSON inspection commands.
- `apps/terminal_workbench_tui` hosts the product shell on top of the reusable
  Workbench runtime.

## Current Operator Experience

The built-in Switchyard shell already supports:

- a home screen listing available sites
- per-site app selection
- generic list/detail screens for resource-backed apps
- custom framework-native app components through `AppDescriptor.tui_component`

The built-in local site currently exposes app descriptors for processes, jobs,
and logs. Process and job resources are mapped end-to-end today. The logs app
descriptor is already in place and can grow on the same seam.

The CLI currently supports:

- `switchyard_cli sites`
- `switchyard_cli apps <site-id>`
- `switchyard_cli local snapshot`

## Packaging Posture

Switchyard is currently delivered as an internal workspace and internal Weld
projection, not as a Hex-first published product suite.

That posture is explicit:

- the Workbench runtime depends on `ex_ratatui` from Hex
- Weld projects the internal `switchyard_foundation` artifact
- `mix release.prepare` builds the prepared bundle,
  `mix release.track` updates `projection/switchyard_foundation`,
  and `mix release.archive` preserves the validated bundle
- `release.publish` remains out of scope

## What The Next Phase Should Mean

Future work should extend breadth and depth without re-litigating the existing
architecture:

- broaden the built-in site and app catalog
- deepen resource/detail/action coverage, especially around logs
- harden the current operator flows
- keep the daemon, shell, framework, and site boundaries explicit
