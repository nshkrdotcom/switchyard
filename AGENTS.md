# Repository Guidelines

## Project Structure
- Root `mix.exs` coordinates the Switchyard workspace.
- Keep docs and examples aligned with the current runtime dependencies.
- Generated `doc/` output should not be edited.

## Execution Plane Stack
- Switchyard is not the owner of lower execution mechanics. When it adopts execution-plane-backed runtimes, depend on the appropriate family kit or facade instead of raw lower internals.
- Document reserved or future execution-plane integration points explicitly so they are not mistaken for active guarantees.

## Gates
- Prefer root `mix ci` when present.
- Otherwise run `mix format`, `mix compile --warnings-as-errors`, `mix test`, `mix credo --strict`, `mix dialyzer`, and `mix docs --warnings-as-errors`.
