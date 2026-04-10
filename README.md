# Switchyard

[![License: MIT](https://img.shields.io/badge/License-MIT-black.svg)](LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-nshkrdotcom%2Fswitchyard-181717.svg?logo=github)](https://github.com/nshkrdotcom/switchyard)

<p align="center">
  <img src="assets/switchyard.svg" alt="Switchyard logo" width="200" height="200" />
</p>

Switchyard is a terminal-native operator workbench for multi-site terminal
applications. It is designed as a non-umbrella Elixir monorepo with a local
control daemon, a generic terminal shell, and pluggable site packages such as
Jido Hive.

The project goal is straightforward:

- host multiple "sites" inside one terminal workbench
- manage jobs, logs, processes, and connections from the same shell
- keep durable local operational state out of the UI process
- let domain systems such as Jido Hive plug in as sites rather than defining
  the platform itself

## Project Status

This repository is greenfield and intentionally staged.

The initial workspace establishes:

- root workspace orchestration with Blitz
- early Weld integration for artifact shaping
- branded documentation and implementation tracking
- the monorepo contract for the packages that follow

## Start Here

- [Guide Index](guides/index.md)
- [Vision](guides/vision.md)
- [Monorepo Strategy](guides/monorepo_strategy.md)
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

## Principles

- the daemon owns long-lived local operational state
- the shell owns navigation and presentation
- site packages own domain mapping and actions
- meaningful operator behavior must exist headlessly beneath the TUI
- Jido Hive remains one site inside the platform, not the platform itself

## License

Switchyard is released under the [MIT License](LICENSE).
