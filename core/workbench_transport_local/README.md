# Switchyard Local Transport

`switchyard_transport_local` is the first headless transport seam for the
daemon.

## Responsibilities

- send request messages to the local daemon
- support local notifications without inventing remote transport too early

## Why This Package Exists

Meaningful behavior must exist beneath the TUI. This package lets tests and
headless tools exercise daemon behavior directly without needing terminal code.

## Current Scope

The initial transport is in-process and deliberately small. It exists to prove
the local daemon seam first.
