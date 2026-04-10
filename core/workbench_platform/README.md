# Switchyard Platform

`switchyard_platform` turns configured site providers into a platform catalog.

## Responsibilities

- load site definitions from provider modules
- enumerate apps and actions for a site
- provide a global catalog view across all configured sites

## Why This Package Exists

The shell and daemon need one consistent way to ask, "what sites exist here and
what can an operator do with them?" This package answers that question without
pulling in UI or transport concerns.

## Current Scope

The current implementation is intentionally small: provider-driven registry
helpers and catalog derivation. It is a seam, not a framework.
