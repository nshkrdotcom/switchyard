# Switchyard TUI

`switchyard_tui` is the terminal host application for Switchyard.

## Responsibilities

- start the terminal-facing application
- own the first shell-backed screen model
- render terminal view data over `ex_ratatui`

## Why This Package Exists

Switchyard is ultimately a terminal workbench. The TUI package is where the
shell and site catalog become an operator-facing terminal experience.

## Current Scope

Current scope:

- home screen with site selection
- site app selection
- generic list/detail rendering for resource-backed apps
- external mounted-app hosting through `site_modules` and `mount_modules`
- a reusable `Switchyard.TUI.Mount` seam for domain-specific UIs

## Build

```bash
cd apps/terminal_workbench_tui
mix deps.get
mix escript.build
./switchyard
```
