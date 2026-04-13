# switchyard_foundation v0.1.0 - API Reference

## Modules

- [Switchyard.Contracts](Switchyard.Contracts.md): Shared contract helpers for the Switchyard platform.

- [Switchyard.Contracts.Action](Switchyard.Contracts.Action.md): Typed action contract.
- [Switchyard.Contracts.ActionProvider](Switchyard.Contracts.ActionProvider.md): Behaviour for executable action providers.
- [Switchyard.Contracts.ActionResult](Switchyard.Contracts.ActionResult.md): Typed action execution result.
- [Switchyard.Contracts.AppDescriptor](Switchyard.Contracts.AppDescriptor.md): Descriptor for an app mounted under a site.
- [Switchyard.Contracts.AppProvider](Switchyard.Contracts.AppProvider.md): Behaviour for site-contributed apps.
- [Switchyard.Contracts.Job](Switchyard.Contracts.Job.md): Typed job contract.
- [Switchyard.Contracts.LogEvent](Switchyard.Contracts.LogEvent.md): Normalized log event contract.
- [Switchyard.Contracts.Resource](Switchyard.Contracts.Resource.md): Typed resource envelope used by shell and CLI surfaces.
- [Switchyard.Contracts.ResourceDetail](Switchyard.Contracts.ResourceDetail.md): Structured detail payload for a resource.
- [Switchyard.Contracts.SearchProvider](Switchyard.Contracts.SearchProvider.md): Behaviour for search providers.
- [Switchyard.Contracts.SearchResult](Switchyard.Contracts.SearchResult.md): Typed search result contract.
- [Switchyard.Contracts.SiteDescriptor](Switchyard.Contracts.SiteDescriptor.md): Descriptor for an installed site.
- [Switchyard.Contracts.SiteProvider](Switchyard.Contracts.SiteProvider.md): Behaviour for installed site providers.
- [Switchyard.Contracts.StreamDescriptor](Switchyard.Contracts.StreamDescriptor.md): Descriptor for a live stream.
- [Switchyard.Daemon](Switchyard.Daemon.md): Local control-plane daemon API.

- [Switchyard.JobRuntime](Switchyard.JobRuntime.md): Job contract helpers and state transitions.

- [Switchyard.LogRuntime](Switchyard.LogRuntime.md): Pure helpers for bounded log retention and filtering.

- [Switchyard.LogRuntime.Buffer](Switchyard.LogRuntime.Buffer.md): Bounded in-memory log buffer.
- [Switchyard.Platform](Switchyard.Platform.md): Provider-driven platform catalog helpers.

- [Switchyard.Platform.Registry](Switchyard.Platform.Registry.md): Registry helpers for site provider modules.

- [Switchyard.ProcessRuntime](Switchyard.ProcessRuntime.md): Minimal managed local process runtime built on ports.

- [Switchyard.ProcessRuntime.Spec](Switchyard.ProcessRuntime.Spec.md): Specification for a managed process.
- [Switchyard.Shell](Switchyard.Shell.md): Pure shell state and reducer helpers for the terminal host.

- [Switchyard.Shell.State](Switchyard.Shell.State.md): Serializable shell state.
- [Switchyard.Site.Local](Switchyard.Site.Local.md): Built-in local operations site.

- [Switchyard.Store.Local](Switchyard.Store.Local.md): Filesystem-backed JSON persistence for local daemon state.

- [Switchyard.Transport.Local](Switchyard.Transport.Local.md): In-VM local transport that speaks to a daemon-like GenServer.

- [Workbench.Accessibility](Workbench.Accessibility.md): Accessible mode helpers.
- [Workbench.Accessibility.Node](Workbench.Accessibility.Node.md): Accessible fallback interaction node.
- [Workbench.Action](Workbench.Action.md): Framework action descriptor.
- [Workbench.ActionRegistry](Workbench.ActionRegistry.md): Helpers for deriving active actions.
- [Workbench.Capabilities](Workbench.Capabilities.md): Negotiated terminal capability flags.
- [Workbench.Cmd](Workbench.Cmd.md): Framework command values resolved by the runtime.
- [Workbench.Component](Workbench.Component.md): Component behaviour for framework-backed screens and widgets.
- [Workbench.ComponentServer](Workbench.ComponentServer.md): GenServer wrapper for supervised framework components.
- [Workbench.ComponentSupervisor](Workbench.ComponentSupervisor.md): Dynamic supervisor for supervised component processes.
- [Workbench.Context](Workbench.Context.md): Explicit immutable runtime context passed to component callbacks.
- [Workbench.Devtools.Driver](Workbench.Devtools.Driver.md): Deterministic reducer-runtime driver helpers for TUI automation.
- [Workbench.Devtools.History](Workbench.Devtools.History.md): Bounded history helpers for devtools capture.
- [Workbench.Devtools.Inspector](Workbench.Devtools.Inspector.md): Builds inspectable runtime snapshot bundles.
- [Workbench.Devtools.Overlay](Workbench.Devtools.Overlay.md): Builds a product-visible debug rail from runtime devtools data.
- [Workbench.Devtools.SessionArtifacts](Workbench.Devtools.SessionArtifacts.md): Creates durable, human-readable session artifact bundles for debug runs.

- [Workbench.EffectRunner](Workbench.EffectRunner.md): Maps framework commands to ExRatatui runtime commands.
- [Workbench.FocusManager](Workbench.FocusManager.md): Focus path helpers.
- [Workbench.FocusTree](Workbench.FocusTree.md): Derived focus traversal metadata.
- [Workbench.Keymap](Workbench.Keymap.md): Structured keybinding helpers.
- [Workbench.Keymap.Binding](Workbench.Keymap.Binding.md): Single keybinding descriptor.
- [Workbench.Layout](Workbench.Layout.md): Declarative layout intent for a node subtree.
- [Workbench.Mouse](Workbench.Mouse.md): Mouse region metadata helpers.
- [Workbench.Node](Workbench.Node.md): Backend-neutral render node.
- [Workbench.RegionMap](Workbench.RegionMap.md): Derived mouse hit-test regions.
- [Workbench.RegionMap.Region](Workbench.RegionMap.Region.md): Resolved mouse region.
- [Workbench.RenderTree](Workbench.RenderTree.md): Resolved render tree derived from declarative nodes.
- [Workbench.RenderTree.Entry](Workbench.RenderTree.Entry.md): Resolved render tree entry.
- [Workbench.Renderer](Workbench.Renderer.md): Renderer behaviour.
- [Workbench.Renderer.ExRatatui](Workbench.Renderer.ExRatatui.md): ExRatatui backend lowering for resolved render trees.
- [Workbench.Runtime](Workbench.Runtime.md): Framework runtime helpers used by thin Workbench-backed terminal apps.
- [Workbench.Runtime.State](Workbench.Runtime.State.md): Runtime state container for thin Workbench-backed terminal apps.
- [Workbench.RuntimeIndex](Workbench.RuntimeIndex.md): Derived runtime indexes for bindings, actions, and subscriptions.
- [Workbench.Screen](Workbench.Screen.md): Runtime screen configuration and viewport metadata.
- [Workbench.Style](Workbench.Style.md): Renderer-neutral node style helpers.
- [Workbench.Subscription](Workbench.Subscription.md): Framework subscription descriptors.
- [Workbench.Theme](Workbench.Theme.md): Theme token helpers for renderer-neutral Workbench styling.
- [Workbench.Transcript](Workbench.Transcript.md): Transcript lines for inline and mixed screen modes.
- [Workbench.Widgets.CommandPalette](Workbench.Widgets.CommandPalette.md): Command palette widget.
- [Workbench.Widgets.Detail](Workbench.Widgets.Detail.md): Detail pane widget.
- [Workbench.Widgets.FieldGroup](Workbench.Widgets.FieldGroup.md): Field grouping widget.
- [Workbench.Widgets.FilePicker](Workbench.Widgets.FilePicker.md): File picker widget.
- [Workbench.Widgets.Form](Workbench.Widgets.Form.md): Form widget.
- [Workbench.Widgets.Help](Workbench.Widgets.Help.md): Generated help widget.
- [Workbench.Widgets.List](Workbench.Widgets.List.md): Selectable list widget.
- [Workbench.Widgets.LogStream](Workbench.Widgets.LogStream.md): Scrollable log stream widget.
- [Workbench.Widgets.Modal](Workbench.Widgets.Modal.md): Modal popup widget.
- [Workbench.Widgets.Paginator](Workbench.Widgets.Paginator.md): Pagination status widget.
- [Workbench.Widgets.Pane](Workbench.Widgets.Pane.md): Bordered content pane.
- [Workbench.Widgets.ProgressBar](Workbench.Widgets.ProgressBar.md): Progress bar widget.
- [Workbench.Widgets.Spinner](Workbench.Widgets.Spinner.md): Async activity indicator.
- [Workbench.Widgets.StatusBar](Workbench.Widgets.StatusBar.md): Single-line status widget.
- [Workbench.Widgets.Table](Workbench.Widgets.Table.md): Tabular data widget.
- [Workbench.Widgets.Tabs](Workbench.Widgets.Tabs.md): Tabs widget.
- [Workbench.Widgets.TextArea](Workbench.Widgets.TextArea.md): Multi-line text area widget.
- [Workbench.Widgets.TextInput](Workbench.Widgets.TextInput.md): Single-line text input widget.
- [Workbench.Widgets.Timer](Workbench.Widgets.Timer.md): Timer display widget.
- [Workbench.Widgets.Tree](Workbench.Widgets.Tree.md): Hierarchical tree widget.
- [Workbench.Widgets.Viewport](Workbench.Widgets.Viewport.md): Scrollable viewport widget.
- [Workbench.Widgets.WidgetList](Workbench.Widgets.WidgetList.md): Variable-height widget list.
- [WorkbenchDevtools](WorkbenchDevtools.md): Public entrypoint for optional Workbench inspection helpers.

- [WorkbenchNodeIr](WorkbenchNodeIr.md): Public entrypoint for the backend-neutral Workbench node IR package.

- [WorkbenchTuiFramework](WorkbenchTuiFramework.md): Public entrypoint for the Workbench TUI framework package.

- [WorkbenchWidgets](WorkbenchWidgets.md): Public entrypoint for reusable Workbench widget constructors.

