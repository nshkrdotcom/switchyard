<p align="center">
  <img src="assets/switchyard.svg" alt="Switchyard logo" width="200" height="200" />
</p>

[![License: MIT](https://img.shields.io/badge/License-MIT-black.svg)](LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-nshkrdotcom%2Fswitchyard-181717.svg?logo=github)](https://github.com/nshkrdotcom/switchyard)

# Switchyard

Switchyard is a terminal-native operator workbench workspace for local
operations and multi-site terminal applications. The repository already
contains the platform contracts, daemon/runtime layers, reusable Workbench TUI
stack, first-party Execution Plane and Jido site surfaces, and runnable
daemon, CLI, and TUI entrypoints.

## Current State

- non-umbrella Elixir workspace with 20 Mix projects:
  root workspace, 13 `core/*` packages, 3 site packages, and 3 runnable apps
- typed contracts, site catalog derivation, daemon transport, and runtime
  packages for processes, jobs, logs, and snapshot storage
- a unified execution plane in `core/workbench_process_runtime` that brokers
  managed processes onto the real `execution_plane` transport surface with
  explicit placement and sandbox metadata
- first-party operator sites for raw Execution Plane state and durable Jido
  state, plus a retained `site_local` reference package for focused local flows
- backend-neutral Workbench node IR, reusable widgets, and a BEAM-native TUI
  runtime bridged onto `ex_ratatui`
- Switchyard product TUI that already supports site navigation, app routing,
  generic list/detail flows, live daemon-backed refresh/actions, and custom
  framework-native app components
- headless CLI and daemon entrypoints that prove meaningful behavior exists
  beneath the UI, including structured process start requests
- Weld projection metadata and tracked projection flow for the internal
  `switchyard_foundation` artifact

Switchyard is no longer just a scaffold. The baseline architecture is in place,
the package boundaries are explicit, and the current work is about extending and
hardening those seams rather than inventing them.

## What You Can Run Today

- `apps/terminal_workbenchd` starts the local daemon with the first-party site
  catalog.
- `apps/terminal_workbench_cli` exposes a JSON-oriented control surface:
  `sites`, `apps <site-id>`, `snapshot`, and `process start`.
- `apps/terminal_workbench_tui` boots the Switchyard shell on top of the
  reusable Workbench runtime and serves operators locally or through the
  `execution_plane_operator_terminal` ingress package.
- `sites/site_execution_plane` maps live runtime substrate state into generic
  processes, operator-terminal, and job views.
- `sites/site_jido` maps durable Jido runs, boundary sessions, and attach
  grants into the same product shell.

## Repository Layout

- `core/*`
  reusable platform packages such as contracts, platform catalog, daemon,
  runtime layers, shell state, node IR, TUI framework, widgets, and devtools
- `sites/*`
  built-in site adapters; the active first-party operator catalog is
  `site_execution_plane` plus `site_jido`, with `site_local` retained as a
  focused local reference site
- `apps/*`
  runnable entrypoints for the TUI shell, headless CLI, and daemon
- `guides/*` and `docs/*`
  workspace architecture, workflow, and delivery references used for HexDocs
  and handoff

## Quick Start

From the repo root:

```bash
mix deps.get
mix mr.deps.get
mix ci
```

Run the daemon:

```bash
cd apps/terminal_workbenchd
iex -S mix
```

Inspect the platform headlessly:

```bash
cd apps/terminal_workbench_cli
mix escript.build
./switchyard_cli sites
./switchyard_cli apps execution_plane
./switchyard_cli snapshot
./switchyard_cli process start --id echo --command "printf 'hello\n'"
```

Run the TUI:

```bash
cd apps/terminal_workbench_tui
mix escript.build
./switchyard --debug
```

Serve the same TUI over SSH for remote operators:

```bash
./switchyard --ssh --ssh-user demo --ssh-password demo
```

Run the TUI over the distributed `ex_ratatui` transport in a trusted BEAM
environment:

```bash
./switchyard --distributed
```

`ex_ratatui` transport is only the operator-access layer for the UI. Managed
process execution still goes through Switchyard's execution plane using
execution surfaces such as `:local_subprocess` and `:ssh_exec`, while remote
operator serving flows through `execution_plane_operator_terminal`.

## Workspace Commands

The repo root is authoritative for workspace-wide quality gates:

- `mix mr.deps.get`
- `mix mr.format --check-formatted`
- `mix mr.compile`
- `mix mr.test`
- `mix mr.credo --strict`
- `mix mr.dialyzer`
- `mix mr.docs --warnings-as-errors`
- `mix weld.verify`
- `mix release.prepare`
- `mix release.track`
- `mix release.archive`
- `mix ci`

## Internal Artifact Flow

`switchyard_foundation` is still an internal welded artifact, not a published
Hex package. The release lifecycle is therefore bundle- and projection-oriented:

1. `mix release.prepare`
2. `mix release.track`
3. `mix release.archive`

`mix release.prepare` builds the prepared artifact bundle under `dist/`.
`mix release.track` updates the orphan-backed
`projection/switchyard_foundation` branch from that bundle so downstream repos
can pin a real generated-source ref before any formal release boundary exists.
`mix release.archive` snapshots the prepared bundle after validation.

The committed workspace dependency stays on the released Hex Weld line. If a
coordinated prerelease Weld validation run is needed, do it with an ordinary
prerelease version bump rather than with repo-local path or git override logic.

## Documentation

Start here if you are orienting yourself in the codebase:

- [Guide Index](guides/index.md)
- [Current State](guides/current_state.md)
- [Vision](guides/vision.md)
- [Monorepo Strategy](guides/monorepo_strategy.md)
- [Package Boundaries](guides/package_boundaries.md)
- [Runtime Model](guides/runtime_model.md)
- [Workspace Workflow](guides/workspace_workflow.md)
- [Testing And Delivery](guides/testing_and_delivery.md)
- [Implementation Checklist](docs/implementation_checklist.md)

## License

Switchyard is released under the [MIT License](LICENSE).
