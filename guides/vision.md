# Vision

Switchyard is intended to be a terminal workbench rather than a larger
single-purpose console.

The platform should combine:

- a local daemon that owns jobs, processes, logs, and sessions
- a generic terminal shell that owns routing, panes, and command UX
- a typed SDK for pluggable sites and apps
- external domain sites built on that SDK

The system should let an operator:

- log into different sites
- launch or stop local process stacks
- tail and filter logs
- inspect job state
- switch between domain apps without abandoning operational context

The intended user experience is not "one TUI per product." It is one durable
terminal shell that can host multiple operator-facing sites with shared global
UX for routing, search, command execution, notifications, jobs, and logs.

That leads to a few hard architectural requirements:

- the shell cannot be the authority for long-lived operational state
- site packages cannot own generic process and log management
- a domain integration must plug into shared contracts instead of redefining
  them
- the same meaningful behavior should be scriptable through a headless surface
  beneath the TUI

Switchyard therefore centers on one local control-plane daemon plus a shell,
site SDK, and app packages layered above it.

This repository will grow toward that model in phases, with the implementation
checklist in `docs/implementation_checklist.md` acting as the live execution
record.
