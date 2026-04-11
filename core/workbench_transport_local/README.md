# Switchyard Local Transport

`switchyard_transport_local` is the first headless transport seam for the
daemon.

## Responsibilities

- send request messages to the local daemon
- support local notifications without inventing remote transport too early

## Quick Start

Validate the package locally:

```bash
cd core/workbench_transport_local
mix deps.get
mix test
```

The transport is intentionally small and in-process. Its job is to prove the
daemon seam first, not to invent a network protocol too early.

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

For workspace-wide validation:

```bash
cd ../..
mix ci
```

## Examples

- [test/switchyard/transport/local_test.exs](test/switchyard/transport/local_test.exs) covers synchronous request forwarding and asynchronous notifications.

## Related Reading

- [Workspace README](../../README.md)
- [Testing And Delivery](../../guides/testing_and_delivery.md)
