# Workbench Node IR

`workbench_node_ir` owns the backend-neutral node and layout vocabulary shared
by the Workbench framework and widget packages.

## Responsibilities

- define the declarative Workbench node tree
- carry layout intent without depending on a specific renderer package
- carry component mount descriptors without depending on runtime ownership
- provide the stable IR that reusable widgets build on

This package is intentionally narrow. Runtime, effects, and renderer lowering
belong in `workbench_tui_framework`.

## Key Modules

- `Workbench.Layout`
- `Workbench.Node`
- `Workbench.Style`
- `Workbench.Theme`

## Current Styling And Layout Surface

- `Workbench.Layout.padding` is now part of resolved child geometry rather than
  inert metadata
- `Workbench.Layout.with_padding/2` can update a layout or a node in-place
- `Workbench.Style` provides renderer-neutral helpers such as `fg/2`,
  `border_fg/2`, `padding/2`, `align/2`, and `highlight_fg/2`
- `Workbench.Theme` provides semantic token resolution for values such as
  `:accent`, `:warning`, and `:focus`

Example:

```elixir
Node.vstack(:root, [Node.text(:title, "Jobs"), Node.text(:body, "steady")])
|> Workbench.Layout.with_padding({1, 1, 0, 0})
|> Workbench.Style.border_fg(:accent)
```

## Package Checks

From this directory:

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix credo --strict
mix dialyzer
mix docs --warnings-as-errors
```
