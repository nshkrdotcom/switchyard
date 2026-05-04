# Switchyard Process Runtime

`switchyard_process_runtime` is the thin execution-plane broker package for
Switchyard managed processes.

## Responsibilities

- validate managed process specs
- normalize execution-surface placement metadata onto the real
  `execution_plane` transport surface
- normalize sandbox requests and reject unsupported capability claims
- route specs to concrete transport adapters
- spawn local OS processes through ports
- execute remote commands through the local `ssh` client
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

The public request map now carries explicit execution metadata:

- `execution_surface`
- `sandbox`
- `args`
- `shell?`
- `cwd`
- `env`
- `clear_env?`
- `user`
- `pty?`

Standalone specs keep that direct shape. Governed specs pass
`governed_authority` and may not also pass direct `env`, `clear_env?`,
`execution_surface`, target, provider, credential, token, default-auth,
global-client, singleton-client, or user fields. In governed mode the process
runtime materializes env, `clear_env?`, execution surface, and authority ref
from `Switchyard.Contracts.GovernedRouteAuthority` before transport
normalization.

Supported execution surfaces today:

- `:local_subprocess`
- `:ssh_exec`

Sandbox posture is explicit. Restricted modes such as `:read_only` or
`:workspace_write` are only accepted when an external runner is provided
through sandbox policy, typically via `command_prefix`.

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

- [test/switchyard/process_runtime_test.exs](test/switchyard/process_runtime_test.exs) demonstrates spec normalization, governed authority rejection/materialization, command preview, transport routing, sandbox validation, process startup, output forwarding, and exit reporting.

## Related Reading

- [Workspace README](../../README.md)
- [Runtime Model](../../guides/runtime_model.md)
