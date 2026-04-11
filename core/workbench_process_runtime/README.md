# Switchyard Process Runtime

`switchyard_process_runtime` manages local subprocess execution for the daemon.

## Responsibilities

- validate managed process specs
- spawn local OS processes through ports
- capture stdout and stderr lines
- expose exit status back to the daemon seam

## Quick Start

Validate the package locally:

```bash
cd core/workbench_process_runtime
mix deps.get
mix test
```

The core interactive seam is:

```elixir
spec = Switchyard.ProcessRuntime.spec!(%{id: "echo", command: "printf 'hello\\n'"})
{:ok, _pid} = Switchyard.ProcessRuntime.start_managed(spec, self())
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

For repo-wide validation:

```bash
cd ../..
mix ci
```

## Examples

- [test/switchyard/process_runtime_test.exs](test/switchyard/process_runtime_test.exs) demonstrates command preview, process startup, output forwarding, and exit reporting.

## Related Reading

- [Workspace README](../../README.md)
- [Runtime Model](../../guides/runtime_model.md)
