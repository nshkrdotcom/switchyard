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

## Site Packages

### `sites/site_local`

The built-in local operations site. It maps daemon-owned process and job state
into generic resources, details, and actions.

## Application Packages

### `apps/terminal_workbench_cli`

Minimal headless CLI over the daemon and local transport. This package proves
that meaningful behavior exists beneath the TUI.

### `apps/terminal_workbench_tui`

The terminal host application. It owns screen composition and rendering over
`ex_ratatui`, not business truth.

### `apps/terminal_workbenchd`

The runnable daemon application that wires together the configured site modules.

## Boundary Rules

1. Core packages do not depend on sites or apps.
2. Site packages do not depend on apps.
3. The TUI does not own durable business truth.
4. If behavior cannot be exercised headlessly, the seam is still wrong.
5. Product-specific integrations belong outside Switchyard core unless they are
   truly generic platform capabilities.
