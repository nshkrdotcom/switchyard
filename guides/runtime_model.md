# Runtime Model

Switchyard is built around a daemon-owned control plane and a transport-aware
execution plane.

## Ownership

### Daemon

The daemon owns long-lived local operational state:

- managed processes
- job lifecycles
- log buffers
- persisted snapshots
- local transport request handling
- execution-surface placement and sandbox metadata for managed processes

The daemon should survive TUI restarts. The UI is a client, not the authority.

### Execution Plane

`core/workbench_process_runtime` is the daemon's execution-plane broker
package.

It owns:

- managed-process spec validation
- execution-surface normalization onto `execution_plane`
- sandbox normalization and capability checks
- transport routing to concrete adapters
- process output and exit reporting back to the daemon

Remote operator serving for the TUI is a separate concern and flows through the
`execution_plane_operator_terminal` package.

The public process spec now carries explicit placement and policy metadata:

- `execution_surface`
- `sandbox`
- `args`
- `shell?`
- `cwd`
- `env`
- `clear_env?`
- `user`
- `pty?`

The currently supported execution surfaces are:

- `:local_subprocess`
- `:ssh_exec`

The currently supported sandbox postures are:

- `:inherit`
- `:danger_full_access`
- restricted modes only when an explicit external runner is supplied through
  sandbox policy

### Shell

The shell owns:

- current route
- selected site and pane focus
- drawer visibility
- notifications
- other ephemeral interaction state

The shell should be pure and reducible from events whenever possible.

### Workbench Runtime

The Workbench runtime owns terminal execution concerns:

- component initialization and update dispatch
- render tree resolution
- effect mapping onto `ex_ratatui`
- key routing, focus data, and mouse region derivation
- accessible rendering fallback seams

The runtime is infrastructure. It should not own business truth or product
workflow state.

### Sites

A site owns domain mapping:

- which apps exist for that site
- which actions are possible
- how snapshots become generic resources
- how details and recommended actions are presented through contracts

### Apps

Apps are runnable entrypoints over the shared core:

- the daemon app starts the local authority
- the CLI exposes headless control and inspection, including structured process
  start requests
- the TUI app is thin product wiring over the Workbench runtime and daemon
  request seam

## Data Flow

The intended flow is:

1. a daemon process starts with a configured set of site modules
2. site providers expose site definitions, apps, actions, and resource mapping
3. the platform registry derives the global catalog from those providers
4. the CLI or Workbench-backed TUI requests data and actions through the daemon seam
5. the daemon updates local runtime state and persists snapshots as needed
6. site providers remap snapshots into typed resources and details

For managed processes specifically:

1. a client submits a process lifecycle request through the daemon action seam
2. the daemon validates and normalizes that spec through the execution plane
3. the selected execution-surface adapter starts the command or rejects the
   request honestly
4. stdout/stderr lines and exit status flow back to the daemon
5. the daemon persists snapshot records that include typed status, status
   reason, exit status, lifecycle timestamps, related jobs, related streams,
   command preview, execution-surface summary, and sandbox summary
6. sites map that metadata into list/detail views and other operator surfaces

Unsupported force-stop, restart, and signal requests return explicit
machine-readable errors instead of claiming transport support that does not
exist.

Process output and job lifecycle events are exposed through daemon stream
descriptors. Log requests support tailing, `after_seq`, and simple level/source
filters while keeping buffers bounded in memory by default.

For the built-in TUI path specifically:

1. the product app boots a root Workbench component
2. the root shows sites, then site apps, then either a generic list/detail app
   or a framework-native custom component
3. the runtime resolves layout and derives focus and mouse indexes
4. effects are lowered onto `ex_ratatui` commands
5. site or integration components route requests back through the daemon seam,
   including process log preview requests
6. the product shell remains a client; it does not become the source of
   process truth

The built-in product TUI can be exposed through multiple operator-access
transports:

- local terminal
- `ex_ratatui` SSH server mode
- `ex_ratatui` distributed mode

Those are UI session transports. They are not execution surfaces for managed
processes.

For the active first-party sites today:

1. the daemon snapshot carries process, operator-terminal, job, and Jido
   operator state
2. process records include command preview, execution-surface summary, and
   sandbox summary
3. `site_execution_plane` maps live runtime state into generic resources and
   details
4. `site_jido` maps durable run/session/grant state into generic resources and
   details
5. the product TUI renders those resources through reusable Workbench widgets
6. the CLI can inspect the same site and snapshot data without rendering

## Why The Daemon Matters

Without the daemon, the TUI would accumulate too much responsibility:

- subprocess ownership
- log fan-out
- retry and lifecycle state
- session persistence
- operational recovery after UI restarts

That is the wrong center of gravity. The daemon gives Switchyard a stable local
authority and keeps UI code replaceable.

Without the Workbench runtime, the product TUI would also accumulate too much
presentation infrastructure:

- keymap plumbing
- focus and mouse routing
- layout resolution
- widget and renderer concerns
- component lifecycle management

That is also the wrong center of gravity. The framework keeps product apps thin
and reusable across integrations.

## Headless Parity

The CLI and tests are not second-class tools. They are proof that the platform
behavior exists beneath the rendering layer.

Every meaningful operator action should be conceptually expressible through:

- a daemon call
- a transport request
- a headless CLI or test seam

If an action exists only because the TUI invented it, the design has drifted.

## Operator Access vs Execution Placement

Switchyard separates two concerns that are easy to conflate:

- operator access to the UI
- placement of managed command execution

Operator access is handled by the TUI host and `ex_ratatui` transports.
Execution placement is handled by the execution plane through
`execution_surface`.

That separation matters because a remote operator SSHing into the TUI is not
the same thing as asking Switchyard to execute a managed command on a remote
host with `:ssh_exec`.
