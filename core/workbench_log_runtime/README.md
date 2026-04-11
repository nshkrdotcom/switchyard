# Switchyard Log Runtime

`switchyard_log_runtime` owns bounded in-memory log buffering helpers.

## Responsibilities

- create bounded log buffers
- append log events
- return recent events
- filter events without re-implementing storage everywhere

## Quick Start

Validate the package locally:

```bash
cd core/workbench_log_runtime
mix deps.get
mix test
```

The smallest useful interactive flow is:

```elixir
buffer = Switchyard.LogRuntime.new_buffer(100)
Switchyard.LogRuntime.recent(buffer)
```

## Developer Workflow

Run package-local checks:

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix credo --strict
mix dialyzer
mix docs --warnings-as-errors
```

Then validate the workspace:

```bash
cd ../..
mix ci
```

## Examples

- [test/switchyard/log_runtime_test.exs](test/switchyard/log_runtime_test.exs) demonstrates bounded buffering and filter queries over structured log events.

## Related Reading

- [Workspace README](../../README.md)
- [Runtime Model](../../guides/runtime_model.md)
