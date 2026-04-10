# Switchyard Contracts

`switchyard_contracts` defines the typed vocabulary for the Switchyard platform.

## Responsibilities

- site descriptors
- app descriptors
- generic resources and resource details
- actions and action results
- streams, jobs, logs, and search results
- provider behaviours for sites, apps, actions, and search

## Why This Package Exists

Every other package in the monorepo needs the same language for describing
sites, apps, resources, and operator actions. This package keeps that language
small, explicit, and testable.

## Current Scope

The package currently focuses on constructor validation and provider behaviours.
It is the base layer for the platform registry, daemon, sites, CLI, and TUI.
