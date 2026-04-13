# Testing And Delivery

Switchyard should continue to grow by proving its seams first. The baseline
workspace is already in place, so delivery work now means extending behavior
without weakening the package boundaries that have already been established.

## TDD / RGR

When introducing behavior:

1. write the failing test first
2. implement the smallest coherent behavior that makes it pass
3. refactor names, boundaries, and docs without weakening the seam

The current workspace follows that rule:

- contracts are covered with constructor and validation tests
- the registry is covered with provider-driven catalog tests
- process, log, job, store, and transport seams each have focused tests
- the daemon is proven through local integration tests
- site adapters are proven by resource/detail mapping tests
- the Workbench runtime is proven through layout, keymap, and command tests
- the product TUI and external integration seams are covered at the first
  meaningful component boundary

## Workspace Quality Gates

The root workspace is authoritative for delivery quality:

- `mix mr.deps.get`
- `mix mr.format --check-formatted`
- `mix mr.compile`
- `mix mr.test`
- `mix mr.credo --strict`
- `mix mr.dialyzer`
- `mix mr.docs --warnings-as-errors`
- `mix weld.verify`
- `mix ci`

`mix ci` is the final green gate for this repository. `mix weld.verify` is the
projection gate for the internal `switchyard_foundation` monolith.

## Internal Monolith Packaging

The welded monolith intentionally opts out of `hex.build` through
`verify: [hex_build: false]`.

That is not a workaround. It is the explicit packaging contract for the current
architecture:

- the Workbench runtime depends on the reducer-runtime API in the forked
  `ex_ratatui` repository
- that dependency is consumed through the published `ex_ratatui` Hex package
- the monolith is therefore still verified as an internal artifact through
  dependency resolution, compile, tests, and docs, while Hex-only packaging
  remains skipped explicitly in Weld

## Recontextualization

If work resumes after a pause or compaction:

1. read `README.md`
2. read `guides/index.md`
3. read `guides/current_state.md`
4. read `guides/package_boundaries.md`
5. read `guides/runtime_model.md`
6. read `guides/workspace_workflow.md`
7. read `docs/implementation_checklist.md`
8. inspect `git status --short --branch`
9. resume from the earliest unchecked checklist item

## Documentation Standard

Repository docs should be self-contained, repo-relative, and written to survive
handoff. HexDocs extras, README content, and package READMEs should describe the
delivered architecture in present tense. Local-machine-specific notes belong
outside the repo, not in the repo docs.
