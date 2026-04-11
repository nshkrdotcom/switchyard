# Switchyard Contracts

`switchyard_contracts` defines the typed vocabulary for the Switchyard
platform.

## Responsibilities

- site descriptors
- app descriptors
- generic resources and resource details
- actions and action results
- streams, jobs, logs, and search results
- provider behaviours for sites, apps, actions, and search

## Quick Start

This is a pure library package. The fastest way to validate it locally is:

```bash
cd core/workbench_contracts
mix deps.get
mix test
```

If you want an interactive entry point, open `iex` and build contracts directly:

```elixir
alias Switchyard.Contracts.{AppDescriptor, SiteDescriptor}

site = SiteDescriptor.new!(%{id: "local", title: "Local", provider: MySite})
AppDescriptor.new!(%{id: "local.processes", site_id: site.id, title: "Processes", provider: MySite})
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

For workspace-wide validation:

```bash
cd ../..
mix ci
```

## Examples

- [test/switchyard/contracts_test.exs](test/switchyard/contracts_test.exs) is the canonical example set for descriptors, resources, actions, jobs, search results, streams, and logs.

## Related Reading

- [Workspace README](../../README.md)
- [Package Boundaries](../../guides/package_boundaries.md)
