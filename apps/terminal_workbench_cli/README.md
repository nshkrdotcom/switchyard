# Switchyard CLI

`switchyard_cli` is the first headless operator surface for Switchyard. It
proves that meaningful platform behavior exists beneath the TUI and stays
available to automation.

## Responsibilities

- inspect configured sites
- inspect site apps
- inspect registered actions
- execute registered actions through the daemon request seam
- fetch the daemon snapshot
- inspect daemon recovery status
- start managed processes through the daemon action request seam
- list, inspect, stop, and read logs for managed processes
- list streams and read stream logs
- keep core platform behavior usable without terminal rendering

## Quick Start

Build the escript and inspect the current local platform state:

```bash
cd apps/terminal_workbench_cli
mix deps.get
mix escript.build
./switchyard_cli sites
./switchyard_cli apps execution_plane
./switchyard_cli actions
./switchyard_cli actions --site execution_plane
./switchyard_cli action run jido.review.refresh --site jido --input-json '{"force":true}'
./switchyard_cli snapshot
./switchyard_cli recovery
./switchyard_cli process start --id echo --command "printf 'hello\n'"
./switchyard_cli process list
./switchyard_cli process inspect echo
./switchyard_cli streams
./switchyard_cli logs logs/echo --tail 20
./switchyard_cli process logs echo --after-seq 10
./switchyard_cli process stop echo --confirm
```

The current CLI surface is intentionally small and JSON-oriented. It is the
fastest way to verify that site registration, daemon state, and transport
behavior still line up. If no named local daemon is already running, the CLI
boots an in-process daemon for the session.

`process start` accepts either:

- explicit flags such as `--command`, `--arg`, `--env`, `--surface-kind`,
  `--ssh-host`, `--sandbox`, and `--sandbox-prefix`
- `--spec-json` with the full structured execution spec

When an option value starts with `-`, pass it with `=` form so `OptionParser`
does not treat it as a flag. For example:

```bash
./switchyard_cli process start --command "mix test" --arg=--trace
./switchyard_cli process start --command "mix test" --sandbox read_only \
  --sandbox-prefix=sh --sandbox-prefix=-lc --sandbox-prefix='exec "$@"' \
  --sandbox-prefix=sandbox
```

Generic `action run` accepts `--site`, `--app`, `--resource kind:id` or
`site_id:kind:id`, `--input-json`, repeated `--input key=value`, and
`--confirm`.

Lifecycle and log commands use the same daemon request seam. `process stop`
requires `--confirm` and is supported for managed local processes. `process
restart` also requires `--confirm` and currently returns machine-readable retry
guidance until restart support is backed by explicit safe restart specs.
`process signal` returns explicit unsupported guidance until transport support
exists. Log commands return stable JSON `LogEvent` objects with per-stream
sequence numbers and output metadata.

## Developer Workflow

Run package-local checks from this directory:

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix credo --strict
mix dialyzer
mix docs --warnings-as-errors
```

Then validate the whole workspace from the repo root:

```bash
cd ../..
mix ci
```

## Examples

- [test/switchyard/cli_test.exs](test/switchyard/cli_test.exs) covers the supported command surface and expected JSON payloads.
- [../../examples/scripts/cli_current_smoke.sh](../../examples/scripts/cli_current_smoke.sh) exercises the current JSON CLI from the source tree.
- The current usage string is `switchyard_cli sites | apps <site-id> | actions [site-id|--site <site-id>] | action run <action-id> [--site <site-id>] [--resource kind:id] [--input-json JSON] [--confirm] | snapshot | recovery | streams | logs <stream-id> | process start|list|inspect|stop|restart|signal|logs`.

## Related Reading

- [Workspace README](../../README.md)
- [Guide Index](../../guides/index.md)
- [Testing And Delivery](../../guides/testing_and_delivery.md)
