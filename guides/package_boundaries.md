# Package Boundaries

Switchyard is intentionally split into three package families under one
workspace root. The current repo shape is already the intended baseline shape
for the platform.

## Root Workspace

The repository root owns:

- workspace orchestration with Blitz
- internal artifact shaping entrypoints with Weld
- shared docs, branding, and delivery tracking
- cross-workspace quality aliases such as `mix ci`

The root must not grow application behavior.

## Core Packages

### `core/workbench_contracts`

The typed platform vocabulary:

- sites
- apps
- resources
- resource details
- actions
- action results
- streams
- jobs
- logs
- search results
- provider behaviours

Every higher layer depends on these contracts.

### `core/workbench_platform`

Registry and catalog helpers that load site providers and derive the global
platform view from them. This package stays small on purpose; it is the typed
catalog seam, not a second runtime.

### `core/workbench_daemon`

The local control-plane daemon API and server implementation. This package owns
the durable local runtime seam for:

- process supervision
- execution-surface and sandbox metadata persistence
- job tracking
- log buffering
- snapshot persistence
- local transport handling

### `core/workbench_transport_local`

The in-process transport seam used by headless clients and tests to speak to the
daemon without inventing a UI-specific protocol.

### `core/workbench_process_runtime`

The unified execution-plane package for Switchyard managed processes. It owns:

- process spec validation
- execution-surface normalization
- sandbox normalization and capability checks
- transport routing
- local subprocess execution
- SSH exec command planning and execution
- output capture and exit reporting

### `core/workbench_log_runtime`

Bounded log buffers and filtering helpers.

### `core/workbench_job_runtime`

Structured job state transitions and progress tracking.

### `core/workbench_store_local`

Local JSON snapshot persistence.

### `core/workbench_shell_core`

Pure shell state and reducers for routing, focus, drawers, and notifications.
This package must stay presentation-agnostic.

### `core/workbench_node_ir`

The backend-neutral Workbench node vocabulary. This package owns:

- declarative node and layout structs
- the stable IR that reusable widget constructors target
- renderer-agnostic layout constraints and node metadata

### `core/workbench_tui_framework`

The reusable BEAM-native TUI runtime. This package owns:

- the component behaviour
- render tree and runtime index structures
- keymap, action, focus, mouse, and transcript primitives
- effect and subscription handling
- the runtime and `ex_ratatui` renderer boundary

It depends on `core/workbench_node_ir` for the node vocabulary instead of
owning that IR directly. This package is infrastructure, not product UI.

### `core/workbench_widgets`

Backend-neutral widget constructors built on the Workbench node IR. This
package provides the reusable widget surface used by Switchyard and external
integrations. It must not depend on the `ex_ratatui`-bearing framework package.

### `core/workbench_devtools`

Optional inspection and development tooling for the Workbench runtime, including
overlay, tree, focus, region, and hot-reload oriented surfaces. This package
should inspect runtime data as data, not by taking a compile-time dependency on
the renderer-bearing framework package unless it truly needs it.

## Site Packages

### `sites/site_execution_plane`

The raw substrate/admin site. It maps daemon-owned live runtime state into
generic resources, details, and actions for:

- processes
- operator terminals
- jobs

### `sites/site_jido`

The durable operator/control-plane site. It maps daemon-exposed
`jido_integration_v2` state into resources for:

- runs
- boundary sessions
- attach grants

### `sites/site_local`

The retained local reference site. It still maps daemon-owned process and job
state into generic resources and details, but it is no longer the active
first-party operator catalog for the product shell.

## Application Packages

### `apps/terminal_workbench_cli`

Minimal headless CLI over the daemon and local transport. This package proves
that meaningful behavior exists beneath the TUI and exposes a structured
process-start seam without depending on rendering.

### `apps/terminal_workbench_tui`

The Switchyard product TUI. It should stay thin:

- product-specific root components
- package-local startup and CLI wiring
- daemon request handling and bootstrapped snapshot loading
- composition of site catalog data into Switchyard views
- operator-access transport configuration for local, SSH, and distributed TUI
  modes through `execution_plane_operator_terminal`

Generic rendering, effects, focus, and widget behavior belong in the Workbench
packages, not here. Generic list/detail behavior should stay reusable; richer
site-specific flows should arrive through framework-native app components.

### `apps/terminal_workbenchd`

The runnable daemon application that wires together the configured site modules.

## Boundary Rules

1. Core packages do not depend on sites or apps.
2. Site packages do not depend on apps.
3. The TUI does not own durable business truth.
4. If behavior cannot be exercised headlessly, the seam is still wrong.
5. Product-specific integrations belong outside Switchyard core unless they are
   truly generic platform capabilities.
6. Framework runtime and widgets belong in reusable core packages, not in the
   product TUI app.
7. External integrations should plug in through `AppDescriptor.tui_component`
   or other generic framework seams, not through compatibility layers.
8. `ex_ratatui` transport serves operator access to the TUI, not managed
   process execution.
