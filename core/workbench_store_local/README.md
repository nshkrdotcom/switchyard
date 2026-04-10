# Switchyard Local Store

`switchyard_store_local` provides local JSON snapshot persistence for the
daemon.

## Responsibilities

- persist named snapshots to disk
- read persisted snapshots back
- enumerate stored snapshot keys

## Why This Package Exists

Durable local state should have one storage seam. The daemon uses this package
to persist snapshots without coupling storage details to UI or site code.

## Current Scope

The current store implementation is intentionally simple: filesystem-backed JSON
snapshots for local daemon state.
