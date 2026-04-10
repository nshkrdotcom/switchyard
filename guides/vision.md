# Vision

Switchyard is intended to be a terminal workbench rather than a larger
single-purpose console.

The platform should combine:

- a local daemon that owns jobs, processes, logs, and sessions
- a generic terminal shell that owns routing, panes, and command UX
- a typed SDK for pluggable sites and apps
- domain sites such as Jido Hive built on that SDK

The system should let an operator:

- log into different sites
- launch or stop local process stacks
- tail and filter logs
- inspect job state
- switch between domain apps without abandoning operational context

This repository will grow toward that model in phases, with the implementation
checklist in `docs/implementation_checklist.md` acting as the live execution
record.
