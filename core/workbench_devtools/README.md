# Workbench Devtools

`workbench_devtools` holds optional inspection and development tooling for the
Workbench runtime.

## Responsibilities

- expose bounded session history helpers
- create durable debug session artifact bundles
- render overlay / debug-rail nodes from runtime devtools data
- provide deterministic reducer-runtime driver helpers for automation
- host development helpers such as file watching and hot-reload plumbing

This package is intentionally optional. Product apps should be able to run
without it.

## Current Surface

- `Workbench.Devtools.SessionArtifacts.runtime_config/1` creates a debug session
  directory and sink suitable for `Workbench.Runtime` devtools capture
- `Workbench.Devtools.Overlay.node/1` renders a debug rail from the current
  devtools map
- `Workbench.Devtools.Driver` wraps runtime snapshot polling plus synthetic key
  and resize injection for deterministic TUI automation
- inspector, render-tree, focus-tree, region-map, focus, event, command, and
  render-stat helpers
- file watching and hot-reload plumbing

## Artifact Shape

The first durable debug bundle is intentionally simple and readable:

- `manifest.json`
- `events.jsonl`
- `commands.jsonl`
- `snapshots.jsonl`
- `latest.json`

This is designed to be usable by both humans and agents after the session has
already exited.

## Package Checks

From this directory:

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix credo --strict
mix dialyzer
mix docs --warnings-as-errors
```
