# Switchyard CLI

`switchyard_cli` is the first headless operator surface for Switchyard.

## Responsibilities

- inspect configured sites
- inspect site apps
- fetch the local daemon snapshot
- prove that meaningful behavior exists beneath the TUI

## Why This Package Exists

The terminal shell cannot be the only way to use the platform. A headless seam
is required for automation, testing, and architecture discipline.

## Current Scope

The current CLI is intentionally minimal and JSON-oriented. It proves the daemon
and transport seams without overcommitting to a large command surface too early.
