# Monorepo Strategy

Switchyard follows a non-umbrella monorepo model.

The top-level `mix.exs` is a workspace root that coordinates child Mix
projects with Blitz. Packaging and future publication shaping will be handled
through Weld.

The target package families are:

- `core/*` for contracts and reusable platform internals
- `sites/*` for pluggable site adapters such as Jido Hive
- `apps/*` for runnable applications such as the TUI shell, CLI, and daemon

This split keeps the dependency graph honest:

- the root orchestrates
- core packages define shared seams
- sites map domain systems onto those seams
- apps host runnable entrypoints

That structure is intentionally similar to the `jido_integration` workspace
pattern rather than an umbrella application.

## Why This Is Not An Umbrella

Umbrellas are useful when all children are fundamentally one application with a
shared build and release story. Switchyard needs a different posture:

- packages must remain independently understandable
- dependency direction needs to stay explicit
- workspace orchestration should not erase package boundaries
- publication and artifact shaping should be possible package-by-package later

Blitz provides the workspace task execution, and Weld is reserved for future
artifact shaping once the package boundaries stabilize.

## Dependency Direction

The intended dependency graph is:

1. root workspace orchestrates only
2. `core/*` depends only on other `core/*` packages and small external libs
3. `sites/*` depends on `core/*` and site-specific client libraries
4. `apps/*` depends on `core/*` and `sites/*`

Reverse edges are a design failure. If a site package needs shell-only state, or
the shell needs to invent behavior that does not exist beneath it, the seam is
wrong.
