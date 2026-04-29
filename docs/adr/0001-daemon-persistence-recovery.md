# ADR 0001: Daemon Persistence And Recovery Semantics

Status: accepted

Date: 2026-04-28

## Context

Switchyard needs durable operator context across daemon restarts, but the
daemon cannot honestly claim that unmanaged OS or remote execution state remains
attached unless the underlying transport proves reconnect support.

## Decision

The daemon persists safe local summaries through `switchyard_store_local`:

- manifest at `daemon/manifest.json`
- current versioned snapshot at `daemon/snapshots/current.json`
- current JSONL journal at `daemon/journals/journal-current.jsonl`
- legacy compatibility snapshot at `daemon/local_snapshot.json`

On boot with a configured store, the daemon reads the manifest, current
snapshot, and journal. Terminal process records remain terminal. Previously
running, starting, or stopping process records recover as `:lost` with
`:daemon_restarted_without_reconnect` unless a future transport-specific
reconnect path proves otherwise.

The daemon snapshot exposes `recovery_status` so CLI, TUI, tests, and examples
can inspect recovery state through the same request seam.

## Consequences

- Recovery is useful for audit/debug visibility without overstating process
  liveness.
- Reconnect support must be added per execution transport and proven before it
  changes recovered process status.
- Future migrations must preserve safe unknown data or fail closed on malformed
  critical persisted records.
- High-volume raw log output remains memory-only by default until stream
  retention policy is implemented.
