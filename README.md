<p align="center">
  <img src="assets/switchyard.svg" alt="Switchyard logo" width="200" height="200" />
</p>

[![License: MIT](https://img.shields.io/badge/License-MIT-black.svg)](LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-nshkrdotcom%2Fswitchyard-181717.svg?logo=github)](https://github.com/nshkrdotcom/switchyard)

# Switchyard

Switchyard is a terminal-native operator workbench workspace for local
operations and multi-site terminal applications. The repository already
contains the platform contracts, daemon/runtime layers, reusable Workbench TUI
stack, built-in local site, and runnable daemon, CLI, and TUI entrypoints.

## Current State

- non-umbrella Elixir workspace with 18 Mix projects:
  root workspace, 13 `core/*` packages, 1 built-in site, and 3 runnable apps
- typed contracts, site catalog derivation, daemon transport, and local runtime
  packages for processes, jobs, logs, and snapshot storage
- backend-neutral Workbench node IR, reusable widgets, and a BEAM-native TUI
  runtime bridged onto `ex_ratatui`
- Switchyard product TUI that already supports site navigation, app routing,
  generic list/detail flows, and custom framework-native app components
- headless CLI and daemon entrypoints that prove meaningful behavior exists
  beneath the UI
- Weld projection metadata and tracked projection flow for the internal
  `switchyard_foundation` artifact

Switchyard is no longer just a scaffold. The baseline architecture is in place,
the package boundaries are explicit, and the current work is about extending and
hardening those seams rather than inventing them.

## What You Can Run Today

- `apps/terminal_workbenchd` starts the local daemon with the first-party site
  catalog.
- `apps/terminal_workbench_cli` exposes a small JSON-oriented control surface:
  `sites`, `apps <site-id>`, and `local snapshot`.
- `apps/terminal_workbench_tui` boots the Switchyard shell on top of the
  reusable Workbench runtime.
- `sites/site_local` currently provides the built-in local site with app
  descriptors for processes, jobs, and logs; processes and jobs are already
  mapped into resources and details.

## Repository Layout

- `core/*`
  reusable platform packages such as contracts, platform catalog, daemon,
  runtime layers, shell state, node IR, TUI framework, widgets, and devtools
- `sites/*`
  built-in site adapters; today that is `site_local`
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
./switchyard_cli apps local
./switchyard_cli local snapshot
```

Run the TUI:

```bash
cd apps/terminal_workbench_tui
mix escript.build
./switchyard --debug
```

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
