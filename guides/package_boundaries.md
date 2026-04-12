# Package Boundaries

Switchyard is intentionally split into three package families under one
workspace root.

## Root Workspace

The repository root owns:

- workspace orchestration with Blitz
- future artifact shaping entrypoints with Weld
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
platform view from them.

### `core/workbench_daemon`

The local control-plane daemon API and server implementation. This package owns
the durable local runtime seam for:

- process supervision
- job tracking
- log buffering
- snapshot persistence
- local transport handling

### `core/workbench_transport_local`

The in-process transport seam used by headless clients and tests to speak to the
daemon without inventing a UI-specific protocol too early.

### `core/workbench_process_runtime`

Managed local subprocess execution and output capture.

### `core/workbench_log_runtime`

Bounded log buffers and filtering helpers.

### `core/workbench_job_runtime`

Structured job state transitions and progress tracking.

### `core/workbench_store_local`

Local JSON snapshot persistence.

### `core/workbench_shell_core`

Pure shell state and reducers for routing, focus, drawers, and notifications.
This package must stay presentation-agnostic.

### `core/workbench_tui_framework`

The greenfield BEAM-native TUI runtime. This package owns:

- the component behaviour
- render tree and runtime index structures
- keymap, action, focus, mouse, and transcript primitives
- effect and subscription handling
- the runtime and `ex_ratatui` renderer boundary

This package must stay product-agnostic.

### `core/workbench_widgets`

Backend-neutral widget constructors built on the Workbench node IR. This
package provides the reusable widget surface used by Switchyard and external
integrations.

### `core/workbench_devtools`

Optional inspection and development tooling for the Workbench runtime, including
overlay, tree, focus, region, and hot-reload oriented surfaces.

## Site Packages

### `sites/site_local`

The built-in local operations site. It maps daemon-owned process and job state
into generic resources, details, and actions.

## Application Packages

### `apps/terminal_workbench_cli`

Minimal headless CLI over the daemon and local transport. This package proves
that meaningful behavior exists beneath the TUI.

### `apps/terminal_workbench_tui`

The Switchyard product TUI. It should stay thin:

- product-specific root components
- package-local startup and CLI wiring
- composition of site catalog data into Switchyard views

Generic rendering, effects, focus, and widget behavior belong in the Workbench
packages, not here.

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
