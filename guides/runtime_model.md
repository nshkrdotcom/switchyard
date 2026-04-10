# Runtime Model

Switchyard is built around a local control-plane daemon.

## Ownership

### Daemon

The daemon owns long-lived local operational state:

- managed processes
- job lifecycles
- log buffers
- persisted snapshots
- local transport request handling

The daemon should survive TUI restarts. The UI is a client, not the authority.

### Shell

The shell owns:

- current route
- selected site and pane focus
- drawer visibility
- notifications
- other ephemeral interaction state

The shell should be pure and reducible from events whenever possible.

### Sites

A site owns domain mapping:

- which apps exist for that site
- which actions are possible
- how snapshots become generic resources
- how details and recommended actions are presented through contracts

### Apps

Apps are runnable entrypoints over the shared core:

- the daemon app starts the local authority
- the CLI exposes headless control and inspection
- the TUI hosts terminal rendering and navigation

## Data Flow

The intended flow is:

1. a daemon process starts with a configured set of site modules
2. site providers expose site definitions, apps, actions, and resource mapping
3. the platform registry derives the global catalog from those providers
4. the CLI or TUI requests data and actions through the daemon seam
5. the daemon updates local runtime state and persists snapshots as needed
6. site providers remap snapshots into typed resources and details

## Why The Daemon Matters

Without the daemon, the TUI would accumulate too much responsibility:

- subprocess ownership
- log fan-out
- retry and lifecycle state
- session persistence
- operational recovery after UI restarts

That is the wrong center of gravity. The daemon gives Switchyard a stable local
authority and keeps UI code replaceable.

## Headless Parity

The CLI and tests are not second-class tools. They are proof that the platform
behavior exists beneath the rendering layer.

Every meaningful operator action should be conceptually expressible through:

- a daemon call
- a transport request
- a headless CLI or test seam

If an action exists only because the TUI invented it, the design has drifted.
