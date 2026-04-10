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
