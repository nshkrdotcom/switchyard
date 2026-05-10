# Repository Guidelines

## Project Structure
- Root `mix.exs` coordinates the Switchyard workspace.
- Keep docs and examples aligned with the current runtime dependencies.
- Generated `doc/` output should not be edited.

## Dependency Sources
- Dependency source selection is handled by `build_support/dependency_sources.exs` and `build_support/dependency_sources.config.exs`.
- Local dependency overrides use `.dependency_sources.local.exs`.
- Dependency source selection must not use environment variables.
- Same-repo workspace package paths may stay in `build_support/dependency_resolver.exs`; cross-repo dependencies belong in the dependency-source manifest.
- Weld checks helper drift, dependency-source manifests, clone/publish checks, and publish order for this repo; keep the committed dependency on the released Hex Weld line.

## Runtime Env
- Runtime application code under `lib/**`, Mix task modules, and examples must not call direct OS env APIs such as `System.get_env`, `System.fetch_env`, `System.put_env`, or `System.delete_env`.
- Runtime/deployment env reads belong in `config/runtime.exs` or a `Config.Provider`.
- Mix tasks and examples should accept explicit flags, app config, or caller-supplied env maps instead of reading or mutating process env.

## Execution Plane Stack
- Switchyard is not the owner of lower execution mechanics. When it adopts execution-plane-backed runtimes, depend on the appropriate family kit or facade instead of raw lower internals.
- Document reserved or future execution-plane integration points explicitly so they are not mistaken for active guarantees.

## Gates
- Prefer root `mix ci` when present.
- Otherwise run `mix format`, `mix compile --warnings-as-errors`, `mix test`, `mix credo --strict`, `mix dialyzer`, and `mix docs --warnings-as-errors`.

## Blitz 0.3.0 operational note

Root workspace Blitz uses published Hex `~> 0.3.0` by default; `.blitz/` is committed compact impact state after green QC. Source and `mix.exs` changes cascade through reverse workspace dependencies; docs-only changes should stay owner-local.
