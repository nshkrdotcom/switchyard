# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project adheres to Semantic
Versioning where practical for published artifacts.

## [Unreleased]

### Added

- Governed route authority contracts for Switchyard dispatch, process env,
  target routing, daemon site routing, and operator transport materialization.
- Non-umbrella workspace structure with reusable core packages, built-in site
  package, and runnable daemon, CLI, and TUI apps.
- Workbench node IR, reusable widgets, and BEAM-native TUI runtime over
  `ex_ratatui`.
- Weld projection metadata for the internal `switchyard_foundation` artifact.
- Generic daemon action execution surfaced through CLI `action run` and TUI
  resource action flows with confirmation.
- Versioned local persistence with manifests, snapshots, journals, recovery
  status, and lost-process recovery semantics.
- Current-working examples for a generic site adapter, daemon smoke flow, and
  CLI smoke flow, plus intentionally future-red proof files.

### Changed

- Split standalone Switchyard env/config behavior from governed routing:
  governed process specs now reject direct env, target, credential, and
  singleton-client fields, and daemon process logs redact materialized env
  values before storage.
- Refreshed the workspace README, guide set, and HexDocs navigation to describe
  the delivered architecture in present tense.
- Updated CLI, TUI, daemon, store, and first-party site docs for action,
  recovery, stream, search, and site-state behavior.
