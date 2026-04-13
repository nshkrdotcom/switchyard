# Vision

Switchyard is a terminal workbench rather than a single-purpose console. The
project now has the baseline architecture needed to pursue that vision without
collapsing back into one oversized TUI application.

The platform combines:

- a local daemon that owns jobs, processes, logs, and sessions
- a generic terminal shell that owns routing, panes, and command UX
- a typed SDK for pluggable sites and apps
- external domain sites built on that SDK

The operator model remains straightforward:

- log into different sites
- launch or stop local process stacks
- tail and filter logs
- inspect job state
- switch between domain apps without abandoning operational context

The target user experience is not "one TUI per product." It is one durable
terminal shell that can host multiple operator-facing sites with shared global
UX for routing, search, command execution, notifications, jobs, and logs.

That requires a few hard architectural constraints:

- the shell cannot be the authority for long-lived operational state
- site packages cannot own generic process and log management
- a domain integration must plug into shared contracts instead of redefining
  them
- the same meaningful behavior should be scriptable through a headless surface
  beneath the TUI

Switchyard therefore centers on one local control-plane daemon plus a shell,
site SDK, reusable TUI framework, and app packages layered above it.

That foundation already exists in this repository:

- the daemon seam is implemented
- the shell state is separated from the product TUI
- the Workbench runtime, widgets, and node IR are split into reusable packages
- the built-in local site maps daemon state into shared contracts
- the CLI and TUI both consume behavior beneath the rendering layer

The next phase is not to invent the architecture. It is to widen the useful
surface area while preserving these boundaries.
