# Switchyard Daemon App

`switchyard_daemon_app` is the runnable OTP application that starts the local
Switchyard daemon with the first-party site catalog.

## Responsibilities

- configure the daemon with site modules
- provide a concrete long-lived local daemon process
- keep daemon runtime wiring separate from daemon internals

## Quick Start

Start the daemon app in one terminal:

```bash
cd apps/terminal_workbenchd
mix deps.get
iex -S mix
```

Then, from another terminal, inspect the current platform state through the
headless CLI:

```bash
cd ../terminal_workbench_cli
mix escript.build
./switchyard_cli local snapshot
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

For repo-wide validation:

```bash
cd ../..
mix ci
```

## Examples

- [test/switchyard/daemon_app_test.exs](test/switchyard/daemon_app_test.exs) verifies that the app wires in the built-in site set correctly.

## Related Reading

- [Workspace README](../../README.md)
- [Runtime Model](../../guides/runtime_model.md)
- [Testing And Delivery](../../guides/testing_and_delivery.md)
