# Switchyard Implementation Checklist

Status: active
Scope: greenfield monorepo bootstrap and foundational platform packages

## Required Reading

Read these before making structural changes:

1. `README.md`
2. `guides/index.md`
3. `guides/vision.md`
4. `guides/monorepo_strategy.md`
5. `build_support/workspace_contract.exs`
6. `build_support/weld_contract.exs`

Reference implementation patterns:

- `~/p/g/n/jido_integration/mix.exs`
- `~/p/g/n/jido_integration/build_support/workspace_contract.exs`
- `~/p/g/n/jido_integration/build_support/weld_contract.exs`

## Invariants

1. The root is a workspace and docs layer, not a true umbrella.
2. The daemon owns durable local operational state.
3. The shell owns terminal UX only.
4. Sites own domain mapping and actions.
5. Jido Hive is one site inside the platform.

## Live Checklist

### Phase 0: Root Workspace Skeleton

- [x] Create the GitHub repository and clone it locally.
- [x] Set the repository description and topics.
- [x] Add branded root docs, license, changelog, and logo asset.
- [x] Add a workspace root `mix.exs` with Blitz and Weld integration.
- [x] Add a professional HexDocs menu structure for the workspace root.
- [x] Validate the root workspace with `mix deps.get`, `mix format`, `mix compile`, and `mix docs`.
- [x] Commit and push the root skeleton.

### Phase 1: Monorepo Bootstrap

- [ ] Expand `build_support/workspace_contract.exs` to include `core/*`, `sites/*`, and `apps/*`.
- [ ] Create the child Mix projects for `core`, `sites`, and `apps`.
- [ ] Add package-local READMEs for every child project.
- [ ] Add root docs describing package boundaries and runtime model.

### Phase 2: Foundational Contracts And Runtime

- [ ] Implement `workbench_contracts` with tests written first.
- [ ] Implement platform registry and local site mapping with tests written first.
- [ ] Implement daemon, process, log, job, store, and local transport foundations with tests written first.
- [ ] Implement CLI and TUI host packages with tests written first where practical.
- [ ] Add the Jido Hive site package over a clean seam.

### Phase 3: Workspace Quality

- [ ] Ensure `mix mr.deps.get` passes.
- [ ] Ensure `mix mr.format --check-formatted` passes.
- [ ] Ensure `mix mr.compile` passes.
- [ ] Ensure `mix mr.test` passes.
- [ ] Ensure `mix mr.credo --strict` passes.
- [ ] Ensure `mix mr.dialyzer` passes.
- [ ] Ensure `mix mr.docs --warnings-as-errors` passes.
- [ ] Ensure `mix ci` passes.
- [ ] Commit and push the finished monorepo foundation.

## Recontextualization Instructions

If work resumes after compaction:

1. Read this file top to bottom.
2. Re-read the required reading list.
3. Confirm current repo state with `git status --short --branch`.
4. Confirm workspace status with `mix help` and `mix ci`.
5. Resume from the earliest unchecked item instead of jumping ahead to UI polish.

## TDD / RGR Rule

Wherever behavior is being introduced, use:

1. red: write the failing test
2. green: implement the minimum coherent behavior
3. refactor: improve names, structure, and documentation without weakening the seam

This repo should grow by proving the seams first, not by accreting screens.
