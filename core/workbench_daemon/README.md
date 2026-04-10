# Switchyard Daemon

`switchyard_daemon` is the local control-plane core for Switchyard.

## Responsibilities

- start and supervise the daemon server
- expose the daemon API used by headless clients and apps
- own local process, job, log, and snapshot state
- answer local transport requests through a stable seam

## Why This Package Exists

The terminal UI should not be the authority for long-lived operational state.
The daemon is the durable center of gravity so that CLI and TUI clients can be
replaceable clients of the same local runtime.

## Current Scope

The current daemon foundation supports:

- listing sites and apps
- reading a local snapshot
- starting a managed process
- fetching captured logs
- persisting a daemon snapshot to local storage
