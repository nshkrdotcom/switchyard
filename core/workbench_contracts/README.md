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
- optional site-level `execute_action/3` callbacks for provider-owned actions
- governed route authority packets for process env, target routing, daemon site
  routing, and operator transport materialization

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

Action scopes are typed as global, site, app, resource, or exact resource
instance scopes. Site providers may optionally implement `execute_action/3`;
the daemon remains responsible for action lookup, scope validation, input
validation, and confirmation before invoking provider-owned execution.

`Switchyard.Contracts.GovernedRouteAuthority` is the governed-mode boundary for
authority-bearing Switchyard runtime settings. It carries the selected
authority ref, route/provider/target refs, credential ref, process env,
execution surface, daemon site modules, and operator transport options. Callers
that pass this packet must not also pass direct env, singleton-client,
default-auth, target-routing, daemon-routing, or operator-transport settings on
the governed request.

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
- [test/switchyard/governed_route_authority_test.exs](test/switchyard/governed_route_authority_test.exs) covers governed authority materialization and bounded operator-transport parsing.

## Related Reading

- [Workspace README](../../README.md)
- [Package Boundaries](../../guides/package_boundaries.md)
