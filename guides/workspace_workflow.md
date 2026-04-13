# Workspace Workflow

The repo root is the authoritative workflow entrypoint. Package-local commands
are useful for tight iteration, but the workspace commands are the final gate.

## Fresh Clone Workflow

From the repo root:

```bash
mix deps.get
mix mr.deps.get
mix ci
```

That sequence does three different jobs:

- `mix deps.get` resolves root workspace dependencies such as Blitz and Weld
- `mix mr.deps.get` resolves child Mix project dependencies across `core/*`,
  `sites/*`, and `apps/*`
- `mix ci` runs the repo-wide quality gates

## Dependency Policy

- `BLITZ_PATH`
  defaults to `../blitz` if that sibling checkout exists; otherwise the root
  workspace uses the Hex package
- `weld`
  stays on the committed Hex dependency line in the repo root
- prerelease Weld validation should happen through normal prerelease version
  bumps, not through committed path/git override logic

If you need deterministic "no local checkout" behavior on a machine that
happens to have those sibling repos, disable the overrides explicitly:

```bash
BLITZ_PATH=disabled mix deps.get
BLITZ_PATH=disabled mix mr.deps.get
```

## Day-To-Day Commands

Use these from the repo root:

- `mix mr.format --check-formatted`
- `mix mr.compile`
- `mix mr.test`
- `mix mr.credo --strict`
- `mix mr.dialyzer`
- `mix mr.docs --warnings-as-errors`
- `mix weld.verify`
- `mix release.prepare`
- `mix release.track`
- `mix release.archive`
- `mix ci`

`mix ci` is the final gate. Use narrower commands only when you are shortening
the local feedback loop.

## Internal Projection Flow

The internal `switchyard_foundation` artifact is tracked through a prepared
bundle and a projection branch, not through a publish step:

1. `mix release.prepare`
2. `mix release.track`
3. `mix release.archive`

`mix release.prepare` builds the artifact bundle under `dist/`.
`mix release.track` updates the orphan-backed
`projection/switchyard_foundation` branch from that bundle so consumers can pin
tracked generated source before any formal release boundary exists.
`mix release.archive` preserves the prepared bundle after validation.

## Package-Local Iteration

When you are actively changing a single package, run local checks from that
package first:

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix credo --strict
mix dialyzer
mix docs --warnings-as-errors
```

Then return to the repo root and run the workspace gate that matches the change
scope.

## Documentation Workflow

The root HexDocs configuration is the workspace-facing documentation surface.
When you add or rename guides:

1. update the guide file under `guides/` or `docs/`
2. add it to root `mix.exs` `docs.extras`
3. add it to `build_support/weld_contract.exs` if it belongs in the projected
   internal docs set
4. run `mix docs --warnings-as-errors`

## Operator Surface Checks

The fastest manual smoke tests are:

- daemon app: `cd apps/terminal_workbenchd && iex -S mix`
- CLI: `cd apps/terminal_workbench_cli && mix escript.build && ./switchyard_cli sites`
- TUI: `cd apps/terminal_workbench_tui && mix escript.build && ./switchyard --debug`

Those should remain thin consumers of the shared core packages rather than
becoming their own centers of gravity.
