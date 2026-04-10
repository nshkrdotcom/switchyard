# Testing And Delivery

Switchyard should grow by proving its seams first.

## TDD / RGR

When introducing behavior:

1. write the failing test first
2. implement the smallest coherent behavior that makes it pass
3. refactor names, boundaries, and docs without weakening the seam

The monorepo foundation in this repository follows that rule:

- contracts are covered with constructor and validation tests
- the registry is covered with provider-driven catalog tests
- process, log, job, store, and transport seams each have focused tests
- the daemon is proven through local integration tests
- site adapters are proven by resource/detail mapping tests
- CLI and TUI hosts are covered at the first meaningful seam

## Workspace Quality Gates

The root workspace is authoritative for delivery quality:

- `mix mr.deps.get`
- `mix mr.format --check-formatted`
- `mix mr.compile`
- `mix mr.test`
- `mix mr.credo --strict`
- `mix mr.dialyzer`
- `mix mr.docs --warnings-as-errors`
- `mix ci`

`mix ci` is the final green gate for this repository.

## Recontextualization

If work resumes after a pause or compaction:

1. read `README.md`
2. read `guides/index.md`
3. read `guides/package_boundaries.md`
4. read `guides/runtime_model.md`
5. read `docs/implementation_checklist.md`
6. inspect `git status --short --branch`
7. resume from the earliest unchecked checklist item

## Documentation Standard

Repository docs should be self-contained, repo-relative, and written to survive
handoff. Local-machine-specific notes belong outside the repo, not in the repo
docs.
