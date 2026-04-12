<p align="center">
  <img src="assets/switchyard.svg" alt="Switchyard logo" width="200" height="200" />
</p>

[![License: MIT](https://img.shields.io/badge/License-MIT-black.svg)](LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-nshkrdotcom%2Fswitchyard-181717.svg?logo=github)](https://github.com/nshkrdotcom/switchyard)

# Switchyard

Switchyard is a terminal-native operator workbench for multi-site terminal
applications. It is built as a non-umbrella Elixir monorepo with a local
control daemon, a pure shell core, a reusable BEAM-native TUI framework, and
pluggable site packages.

The project goal is straightforward:

- host multiple "sites" inside one terminal workbench
- manage jobs, logs, processes, and connections from the same shell
- keep durable local operational state out of the UI process
- let domain systems plug in as external sites rather than defining the
  platform itself

## Project Status

This repository is greenfield and intentionally staged.

The current foundation establishes:

- root workspace orchestration with Blitz
- early Weld integration for artifact shaping
- branded documentation and implementation tracking
- typed contracts for sites, apps, resources, actions, jobs, and logs
- a local daemon seam for process, job, log, and snapshot ownership
- a reusable Workbench runtime, widget, and devtools layer under `core/*`
- a thin Switchyard product TUI over that framework
- a framework-native component seam so external repos can contribute real TUI
  components without changing Switchyard core

## Start Here

- [Guide Index](guides/index.md)
- [Vision](guides/vision.md)
- [Monorepo Strategy](guides/monorepo_strategy.md)
- [Package Boundaries](guides/package_boundaries.md)
- [Runtime Model](guides/runtime_model.md)
- [Testing And Delivery](guides/testing_and_delivery.md)
- [Implementation Checklist](docs/implementation_checklist.md)

## Planned Monorepo Shape

```text
switchyard/
  mix.exs
  build_support/
  core/
  sites/
  apps/
  guides/
  docs/
```

The repo root is a workspace and documentation layer. It is not a true umbrella
application.

## Package Families

### `core/*`

Reusable platform internals:

- `workbench_contracts`
- `workbench_platform`
- `workbench_daemon`
- `workbench_transport_local`
- `workbench_process_runtime`
- `workbench_log_runtime`
- `workbench_job_runtime`
- `workbench_store_local`
- `workbench_shell_core`
- `workbench_tui_framework`
- `workbench_widgets`
- `workbench_devtools`

### `sites/*`

Pluggable site adapters:

- `site_local`

### `apps/*`

Runnable entrypoints:

- `terminal_workbench_tui`
- `terminal_workbench_cli`
- `terminal_workbenchd`

## Principles

- the daemon owns long-lived local operational state
- the shell owns navigation and presentation
- the Workbench runtime owns terminal rendering, actions, focus, and effects
- site packages own domain mapping and actions
- meaningful operator behavior must exist headlessly beneath the TUI
- external product integrations must remain outside Switchyard core

## Workspace Commands

The repo root uses Blitz to run child Mix projects as one workspace:

- `mix mr.deps.get`
- `mix mr.format`
- `mix mr.compile`
- `mix mr.test`
- `mix mr.credo --strict`
- `mix mr.dialyzer`
- `mix mr.docs --warnings-as-errors`
- `mix ci`

## License

Switchyard is released under the [MIT License](LICENSE).
