# Switchyard Examples

This directory holds runnable examples that prove the real Switchyard seams,
not parallel demo scaffolding.

## Current Example

`full_featured_workbench.exs` is the primary example. It exercises:

- the actual `Switchyard.TUI.run/1` startup path
- provider-driven site and app catalog assembly
- a custom `Workbench.Component` mounted through `AppDescriptor.tui_component`
- a mounted supervised child actor inside that custom component, owned by
  `Workbench.Runtime` rather than by product-local state
- generic list/detail apps for site-owned resources
- `Workbench.Cmd.request/3`, `Workbench.Cmd.async/2`, `Workbench.Cmd.after_ms/2`,
  and `Workbench.Cmd.batch/1`
- `Workbench.Subscription.interval/4` and `Workbench.Subscription.once/4`
- runtime inspection through `ExRatatui.Runtime.snapshot/1`, trace toggles, and
  retained trace events rendered in-app
- render suppression through `render?: false` for quiet runtime snapshot polling
- synthetic headless input through `ExRatatui.Runtime.inject_event/2`
- distributed listener / attach mode through the same `Switchyard.TUI.App`
- ex_ratatui-backed rendering through tabs, tables, lists, panes, detail panes,
  spinners, gauges, status bars, and a row-scrolled variable-height
  `WidgetList`
- the normalized style/layout surface through `Workbench.Style`,
  `Workbench.Theme`, and `Workbench.Layout.with_padding/2`

The example includes two sites:

- `Fleet Demo` with a custom `Control Room` plus generic `Runbooks` and
  `Incidents` apps
- `Local` using the built-in site adapter for process and job views

## Run It

From the repo root:

```bash
elixir examples/full_featured_workbench.exs
```

Useful variants:

```bash
elixir examples/full_featured_workbench.exs --open-app control-room
elixir examples/full_featured_workbench.exs --open-app runbooks
elixir examples/full_featured_workbench.exs --describe
elixir examples/full_featured_workbench.exs --smoke
elixir --sname switchyard_smoke --cookie demo examples/full_featured_workbench.exs --distributed-smoke
elixir --sname switchyard_demo --cookie demo examples/full_featured_workbench.exs --distributed
elixir --sname operator --cookie demo examples/full_featured_workbench.exs --attach switchyard_demo@YOUR_HOST
```

## Control Room Keys

- `Left` / `Right`: switch tabs
- `Up` / `Down`: move the current selection
- `r`: refresh the dashboard through the request handler
- `d`: request a canary deploy for the selected service
- `a`: acknowledge the selected incident
- `o`: jump directly to the runtime tab
- `s`: request an on-demand runtime snapshot
- `t`: toggle runtime trace capture
- `x`: run a failing async diagnostic probe
- `Ctrl+Q`: quit

## Success Gates

The example is doing its job if all of the following are true:

- the home screen shows `Fleet Demo` and `Local`
- the `Fleet Demo` site opens `Control Room`, `Runbooks`, and `Incidents`
- `Control Room` animates over time without blocking the BEAM
- the mounted control-loop actor keeps ticking without product-local child state
- manual refresh and deploy actions update the status line and event stream
- the runtime tab shows retained reducer trace events in a row-scrolled
  variable-height `WidgetList`
- runtime snapshot polling continues without forcing a redundant frame on every
  poll tick
- toggling trace and running the failing diagnostic probe update both the runtime
  sidebar and the status line
- generic `Runbooks` and `Incidents` apps render list/detail flows without any
  custom component code
- `--smoke` exits cleanly and reports render/subscription/trace activity
- `--distributed-smoke` exits cleanly and reports distributed-server render and
  trace activity
- `--distributed` prints a working attach command for a second distributed node

## Notes

- The example uses `Mix.install/1` with the local `apps/terminal_workbench_tui`
  package, so it stays outside the workspace contract while still using the
  real app and dependency graph.
- `--smoke` runs the same example in `test_mode` and drives it through
  `ExRatatui.Runtime.inject_event/2`, so it validates the reducer runtime
  through the same headless event path used by the upstream runtime tests.
