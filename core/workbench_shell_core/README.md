# Switchyard Shell Core

`switchyard_shell` holds pure shell state for the terminal workbench.

## Responsibilities

- route and selected-site state
- focused pane state
- drawer visibility
- notifications

## Why This Package Exists

The shell should be reducible, testable, and presentation-agnostic. Terminal
rendering belongs above this layer, not inside it.

## Current Scope

The current shell core proves the reducer seam for global shell interaction
state. More advanced navigation and layout behavior can grow from this base.
