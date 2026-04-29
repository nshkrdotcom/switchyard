# Switchyard Platform

`switchyard_platform` turns configured site providers into a platform catalog.

## Responsibilities

- load site definitions from provider modules
- enumerate apps and actions for a site
- enumerate, fetch, validate, and resource-filter action definitions
- provide a global catalog view across all configured sites

## Quick Start

This package is a pure registry/catalog seam. The fastest validation path is:

```bash
cd core/workbench_platform
mix deps.get
mix test
```

Its job is intentionally small: provider-driven registry helpers and catalog
derivation. The registry validates action definitions and duplicate action IDs,
but it does not execute actions or mutate daemon state.

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

- [test/switchyard/platform_test.exs](test/switchyard/platform_test.exs) shows provider registration, site/app/action lookup, and flat catalog generation.

## Related Reading

- [Workspace README](../../README.md)
- [Package Boundaries](../../guides/package_boundaries.md)
