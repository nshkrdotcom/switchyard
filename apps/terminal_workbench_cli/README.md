# Switchyard CLI

`switchyard_cli` is the first headless operator surface for Switchyard. It
proves that meaningful platform behavior exists beneath the TUI and stays
available to automation.

## Responsibilities

- inspect configured sites
- inspect site apps
- fetch the daemon snapshot
- start managed processes through a structured daemon request seam
- keep core platform behavior usable without terminal rendering

## Quick Start

Build the escript and inspect the current local platform state:

```bash
cd apps/terminal_workbench_cli
mix deps.get
mix escript.build
./switchyard_cli sites
./switchyard_cli apps execution_plane
./switchyard_cli snapshot
./switchyard_cli process start --id echo --command "printf 'hello\n'"
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
- The current usage string is `switchyard_cli sites | apps <site-id> | snapshot | process start [--command CMD | --spec-json JSON]`.

## Related Reading

- [Workspace README](../../README.md)
- [Guide Index](../../guides/index.md)
- [Testing And Delivery](../../guides/testing_and_delivery.md)
