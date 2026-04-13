# Switchyard Implementation Checklist

Status: baseline delivered
Scope: current workspace architecture, Workbench framework extraction,
Switchyard TUI rewrite, integration migration, and delivery verification

## Required Reading

Read these before making structural changes:

1. `README.md`
2. `guides/index.md`
3. `guides/current_state.md`
4. `guides/vision.md`
5. `guides/monorepo_strategy.md`
6. `guides/package_boundaries.md`
7. `guides/runtime_model.md`
8. `guides/workspace_workflow.md`
9. `guides/testing_and_delivery.md`
10. `build_support/workspace_contract.exs`
11. `build_support/dependency_resolver.exs`
12. `build_support/weld_contract.exs`
13. `core/workbench_node_ir/README.md`
14. `core/workbench_tui_framework/README.md`
15. `core/workbench_widgets/README.md`
16. `core/workbench_devtools/README.md`
17. `apps/terminal_workbench_tui/README.md`
18. `apps/terminal_workbench_tui/lib/switchyard/tui/root.ex`
19. `apps/terminal_workbench_tui/lib/switchyard/tui/state.ex`
20. `core/workbench_tui_framework/lib/workbench/runtime.ex`
21. `core/workbench_tui_framework/lib/workbench/effects.ex`
22. `../ex_ratatui/lib/ex_ratatui/command.ex`
23. `../ex_ratatui/lib/ex_ratatui/subscription.ex`

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
- [x] Add `core/workbench_node_ir`.
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
   `ex_ratatui` dependency
2. that API is now consumed through the published `ex_ratatui` Hex package
3. the monolith is therefore still verified as an internal artifact with full
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
