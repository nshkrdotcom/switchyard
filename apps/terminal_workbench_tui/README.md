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

The current TUI foundation is intentionally small:

- initial shell state
- a home-screen view model
- a draw-spec that proves the render seam

That keeps the UI honest while the daemon and site contracts mature.
