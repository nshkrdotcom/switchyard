# Switchyard Implementation Checklist

Status: complete
Scope: greenfield Workbench framework extraction, Switchyard TUI rewrite,
integration migration, and delivery verification

## Required Reading

Read these before making structural changes:

1. `README.md`
2. `guides/index.md`
3. `guides/vision.md`
4. `guides/monorepo_strategy.md`
5. `guides/package_boundaries.md`
6. `guides/runtime_model.md`
7. `guides/testing_and_delivery.md`
8. `build_support/workspace_contract.exs`
9. `build_support/dependency_resolver.exs`
10. `build_support/weld_contract.exs`
11. `core/workbench_tui_framework/README.md`
12. `core/workbench_widgets/README.md`
13. `core/workbench_devtools/README.md`
14. `apps/terminal_workbench_tui/README.md`
15. `apps/terminal_workbench_tui/lib/switchyard/tui/root.ex`
16. `apps/terminal_workbench_tui/lib/switchyard/tui/state.ex`
17. `core/workbench_tui_framework/lib/workbench/runtime.ex`
18. `core/workbench_tui_framework/lib/workbench/effects.ex`
19. `../ex_ratatui/lib/ex_ratatui/command.ex`
20. `../ex_ratatui/lib/ex_ratatui/subscription.ex`

## Invariants

1. The root is a workspace and docs layer, not a true umbrella.
2. The daemon owns durable local operational state.
3. The shell owns pure product navigation state.
4. The Workbench runtime owns generic terminal execution concerns.
5. Sites own domain mapping and actions.
6. Greenfield solutions only: no workarounds, no compatibility shims, no
   backwards-compatibility layers.

## Live Checklist

### Phase 0: Baseline

- [x] Confirm repo state with `git status --short --branch`.
- [x] Confirm required reading against the current codebase.
- [x] Confirm root `mix ci` is green after the current implementation run.

### Phase 1: Framework Packages

- [x] Add `core/workbench_tui_framework`.
- [x] Add `core/workbench_widgets`.
- [x] Add `core/workbench_devtools`.
- [x] Update dependency resolution and Weld roots for the new packages.
- [x] Keep package docs and READMEs aligned with the delivered public surface.

### Phase 2: Framework Runtime

- [x] Add the Workbench component contract.
- [x] Add context, screen, capability, node, and runtime index structures.
- [x] Add render tree, focus tree, and region map structures.
- [x] Add keymap, action, effect, transcript, and renderer seams.
- [x] Add the thin runtime bridge to `ex_ratatui`.
- [x] Expand runtime tests as the public surface grows.

### Phase 3: Product TUI Rewrite

- [x] Replace the legacy mounted-app path with framework-native components.
- [x] Introduce a thin product app bridge over `Workbench.Runtime`.
- [x] Add a Switchyard root component and product state module.
- [x] Delete the old `Command`, `Controller`, `Keymap`, `Model`, `Mount`,
  `Renderer`, and `ScreenUI` modules.
- [x] Keep the daemon as the operational authority.

### Phase 4: Integration Migration

- [x] Migrate Jido Hive to `AppDescriptor.tui_component`.
- [x] Replace `RoomsMount` with a framework-native component.
- [x] Move room/runtime/view integration to Workbench widgets and commands.
- [x] Re-prove the integration seam with tests.

### Phase 5: Docs And Delivery

- [x] Update all repo guides and package READMEs to match the delivered
  architecture.
- [x] Run `mix mr.format --check-formatted`.
- [x] Run `mix mr.compile`.
- [x] Run `mix mr.test`.
- [x] Run `mix mr.credo --strict`.
- [x] Run `mix mr.dialyzer`.
- [x] Run `mix mr.docs --warnings-as-errors`.
- [x] Run `mix weld.verify`.
- [x] Run root `mix ci`.

## Final Validation Record

- [x] `mix ci`
- [x] `mix weld.verify`
- [x] `mix mr.compile`
- [x] `mix test` in `jido_hive_switchyard_site`
- [x] `mix test` in `jido_hive_switchyard_tui`
- [x] `mix mr.compile` in `~/p/g/n/jido_hive`

## Packaging Note

The welded `switchyard_foundation` monolith intentionally sets
`verify: [hex_build: false]`.

Reason:

1. the runtime is designed against the reducer-runtime API in the forked
   `ex_ratatui` checkout at `~/p/g/n/ex_ratatui`
2. that API is currently consumed as a git dependency pinned by commit
3. Hex packages cannot depend on git dependencies
4. the monolith is therefore verified as an internal artifact with full
   `deps.get`, compile, test, and docs gates, while `hex.build` is explicitly
   skipped through Weld rather than failing implicitly

## Recontextualization Instructions

If work resumes after compaction:

1. Read this file top to bottom.
2. Re-read the required reading list.
3. Confirm current repo state with `git status --short --branch`.
4. Confirm workspace state with `mix mr.compile`, `mix mr.test`, and `mix ci`.
5. Resume from the earliest unchecked item.

## TDD / RGR Rule

Wherever behavior is being introduced, use:

1. red: write the failing test
2. green: implement the minimum coherent behavior
3. refactor: improve names, structure, and documentation without weakening the
   seam

The framework and product TUI should continue to grow by proving the seam first
and only then broadening the surface.
