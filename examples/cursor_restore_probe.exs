#!/usr/bin/env elixir

repo_root = Path.expand("..", __DIR__)
project_path = Path.join(repo_root, "apps/terminal_workbench_tui")
hex_home = Path.join(repo_root, ".tmp/example_hex")
mix_home = Path.join(repo_root, ".tmp/example_mix")

File.mkdir_p!(hex_home)
File.mkdir_p!(mix_home)

System.put_env("HEX_HOME", hex_home)
System.put_env("MIX_HOME", mix_home)

Mix.start()

Mix.Project.in_project(:switchyard_tui, project_path, fn _module ->
  Mix.Task.run("deps.get")
  Mix.Task.run("compile")
end)

alias ExecutionPlane.OperatorTerminal
alias ExRatatui.Event
alias ExRatatui.Layout
alias ExRatatui.Layout.Rect
alias ExRatatui.Style
alias ExRatatui.Widgets.{Block, Paragraph}
alias Switchyard.Contracts.{AppDescriptor, Resource, ResourceDetail, SiteDescriptor}
alias Switchyard.TUI

defmodule CursorRestoreProbe.OperatorApp do
  @moduledoc false

  use ExRatatui.App

  @impl true
  def mount(_opts) do
    {:ok, %{label: "ExecutionPlane.OperatorTerminal -> ExRatatui.App"}}
  end

  @impl true
  def render(state, frame) do
    area = %Rect{x: 0, y: 0, width: frame.width, height: frame.height}

    [header_area, body_area, footer_area] =
      Layout.split(area, :vertical, [{:length, 3}, {:min, 0}, {:length, 5}])

    header = %Paragraph{
      text: "  Switchyard Cursor Restore Probe",
      style: %Style{fg: :cyan, modifiers: [:bold]},
      block: %Block{
        borders: [:all],
        border_type: :rounded,
        border_style: %Style{fg: :dark_gray}
      }
    }

    body = %Paragraph{
      text: """
        Mode:
          #{state.label}

        This bypasses Switchyard.TUI.App and exercises only the operator-terminal
        wrapper around a trivial ExRatatui app.

        Press Ctrl+Q to quit.
      """,
      style: %Style{fg: :white},
      block: %Block{
        title: "Scope",
        borders: [:all],
        border_type: :rounded,
        border_style: %Style{fg: :cyan}
      }
    }

    footer = %Paragraph{
      text: """
        Compare this with:
          elixir examples/cursor_restore_probe.exs --mode switchyard-minimal
      """,
      style: %Style{fg: :dark_gray},
      block: %Block{
        title: "Next",
        borders: [:all],
        border_type: :rounded,
        border_style: %Style{fg: :dark_gray}
      }
    }

    [{header, header_area}, {body, body_area}, {footer, footer_area}]
  end

  @impl true
  def handle_event(%Event.Key{code: "q", modifiers: modifiers, kind: "press"}, state)
      when modifiers in [[], ["ctrl"]] do
    {:stop, state}
  end

  def handle_event(_event, state), do: {:noreply, state}
end

defmodule CursorRestoreProbe.ReducerApp do
  @moduledoc false

  use ExRatatui.App, runtime: :reducer

  alias ExRatatui.Event

  @impl true
  def init(_opts) do
    {:ok, %{label: "ExecutionPlane.OperatorTerminal -> reducer ExRatatui.App"}}
  end

  @impl true
  def render(state, frame) do
    CursorRestoreProbe.OperatorApp.render(state, frame)
  end

  @impl true
  def update({:event, %Event.Key{code: "q", modifiers: modifiers, kind: "press"}}, state)
      when modifiers in [[], ["ctrl"]] do
    {:stop, state}
  end

  def update(_msg, state), do: {:noreply, state}
end

defmodule CursorRestoreProbe.Site do
  @moduledoc false

  @behaviour Switchyard.Contracts.SiteProvider

  @impl true
  def site_definition do
    SiteDescriptor.new!(%{
      id: "example",
      title: "Example",
      provider: __MODULE__,
      kind: :remote
    })
  end

  @impl true
  def apps do
    [
      AppDescriptor.new!(%{
        id: "example.notes",
        site_id: "example",
        title: "Notes",
        provider: __MODULE__,
        resource_kinds: [:note],
        route_kind: :list_detail
      })
    ]
  end

  @impl true
  def actions, do: []

  @impl true
  def resources(_snapshot) do
    [
      Resource.new!(%{
        site_id: "example",
        kind: :note,
        id: "note-1",
        title: "First note",
        subtitle: "ready",
        status: :ready,
        summary: "minimal Switchyard repro resource"
      })
    ]
  end

  @impl true
  def detail(resource, _snapshot) do
    ResourceDetail.new!(%{
      resource: resource,
      sections: [%{title: "Detail", lines: ["id: #{resource.id}", "title: #{resource.title}"]}],
      recommended_actions: ["Inspect"]
    })
  end
end

defmodule CursorRestoreProbe do
  @moduledoc false

  alias CursorRestoreProbe.OperatorApp
  alias CursorRestoreProbe.ReducerApp
  alias CursorRestoreProbe.Site
  alias ExecutionPlane.OperatorTerminal
  alias Switchyard.TUI

  @snapshot %{
    processes: [],
    jobs: [],
    operator_terminals: [],
    runs: [],
    boundary_sessions: [],
    attach_grants: []
  }

  def run(argv) do
    {opts, positional, _invalid} =
      OptionParser.parse(argv, strict: [mode: :string], aliases: [m: :mode])

    case opts[:mode] || List.first(positional) || "switchyard-minimal" do
      "operator-terminal" ->
        run_operator_terminal(OperatorApp)

      "operator-terminal-reducer" ->
        run_operator_terminal(ReducerApp)

      "switchyard-minimal" ->
        run_switchyard_minimal()

      "help" ->
        usage(nil)

      other ->
        usage(other)
    end
  end

  defp run_operator_terminal(mod) do
    :ok = ensure_operator_terminal_runtime()

    terminal_id = "cursor-probe-#{System.unique_integer([:positive])}"

    {:ok, pid} =
      OperatorTerminal.start_link(
        mod: mod,
        app_opts: [],
        surface_kind: :local_terminal,
        surface_ref: terminal_id
      )

    await_exit(pid)
  end

  defp run_switchyard_minimal do
    case TUI.run(
           request_handler: &request_handler/2,
           snapshot: @snapshot,
           site_modules: [Site],
           open_app: "example.notes"
         ) do
      :ok -> :ok
      {:error, reason} -> raise "switchyard-minimal failed: #{inspect(reason)}"
    end
  end

  defp request_handler(:local_snapshot, _opts), do: @snapshot
  defp request_handler(request, _opts), do: {:error, {:unsupported_request, request}}

  defp ensure_operator_terminal_runtime do
    case Application.ensure_all_started(:execution_plane_operator_terminal) do
      {:ok, _started_apps} -> :ok
      {:error, reason} -> raise "operator terminal boot failed: #{inspect(reason)}"
    end
  end

  defp await_exit(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    end
  end

  defp usage(nil) do
    IO.puts("""
    Usage:
      elixir examples/cursor_restore_probe.exs --mode operator-terminal
      elixir examples/cursor_restore_probe.exs --mode operator-terminal-reducer
      elixir examples/cursor_restore_probe.exs --mode switchyard-minimal

    Modes:
      operator-terminal          operator terminal + callback ExRatatui app
      operator-terminal-reducer  operator terminal + reducer ExRatatui app
      switchyard-minimal         minimal Switchyard.TUI.run/1 path
    """)

    System.halt(0)
  end

  defp usage(other) do
    IO.puts("Unknown mode: #{other}")
    usage(nil)
  end
end

CursorRestoreProbe.run(System.argv())

IO.puts("""

Cursor restore probe exited.

Inspect the shell cursor now.
Report back with:
  1. the mode you ran
  2. whether the shell cursor is blinking normally after Ctrl+Q
""")
