defmodule WorkbenchDevtools do
  @moduledoc """
  Public entrypoint for optional Workbench inspection helpers.
  """
end

defmodule Workbench.Devtools.History do
  @moduledoc "Bounded history helpers for devtools capture."

  @spec push([term()], term(), pos_integer()) :: [term()]
  def push(entries, entry, limit) when is_list(entries) and is_integer(limit) and limit > 0 do
    [entry | entries] |> Enum.take(limit)
  end
end

defmodule Workbench.Devtools.Inspector do
  @moduledoc "Builds inspectable runtime snapshot bundles."

  @spec snapshot(keyword()) :: map()
  def snapshot(opts) do
    %{
      enabled?: Keyword.get(opts, :enabled?, false),
      artifact_dir: Keyword.get(opts, :artifact_dir),
      latest: Keyword.get(opts, :latest),
      events: Keyword.get(opts, :events, []),
      commands: Keyword.get(opts, :commands, []),
      subscriptions: Keyword.get(opts, :subscriptions, []),
      snapshots: Keyword.get(opts, :snapshots, [])
    }
  end
end

defmodule Workbench.Devtools.SessionArtifacts do
  @moduledoc """
  Creates durable, human-readable session artifact bundles for debug runs.
  """

  @default_base_dir Path.expand("tmp/switchyard_debug")

  @spec runtime_config(keyword()) :: map()
  def runtime_config(opts \\ []) do
    artifact_dir = prepare_artifact_dir(opts)
    session_label = opts |> Keyword.get(:session_label, "session") |> sanitize_path_segment()
    history_limit = Keyword.get(opts, :history_limit, 50)

    write_json!(
      Path.join(artifact_dir, "manifest.json"),
      %{
        session_label: session_label,
        artifact_dir: artifact_dir,
        history_limit: history_limit,
        created_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    )

    %{
      enabled?: true,
      artifact_dir: artifact_dir,
      history_limit: history_limit,
      session_label: session_label,
      sink: sink(artifact_dir)
    }
  end

  @spec sink(String.t()) :: (map() -> :ok)
  def sink(artifact_dir) when is_binary(artifact_dir) do
    fn entry ->
      append(artifact_dir, entry)
      :ok
    end
  end

  @spec append(String.t(), map()) :: :ok
  def append(artifact_dir, %{kind: kind, entry: entry})
      when is_binary(artifact_dir) and is_atom(kind) and is_map(entry) do
    file_name =
      case kind do
        :event -> "events.jsonl"
        :command -> "commands.jsonl"
        :snapshot -> "snapshots.jsonl"
        other -> "#{other}.jsonl"
      end

    File.write!(Path.join(artifact_dir, file_name), Jason.encode!(entry) <> "\n", [:append])

    if kind == :snapshot do
      write_json!(Path.join(artifact_dir, "latest.json"), entry)
    end

    :ok
  end

  defp prepare_artifact_dir(opts) do
    base_dir =
      opts
      |> Keyword.get(:base_dir, @default_base_dir)
      |> Path.expand()

    label = opts |> Keyword.get(:session_label, "session") |> sanitize_path_segment()
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%dT%H%M%SZ")
    artifact_dir = Path.join(base_dir, "#{timestamp}-#{label}")
    File.mkdir_p!(artifact_dir)
    artifact_dir
  end

  defp write_json!(path, data), do: File.write!(path, Jason.encode_to_iodata!(data, pretty: true))

  defp sanitize_path_segment(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]+/u, "-")
    |> String.trim("-")
    |> case do
      "" -> "session"
      sanitized -> sanitized
    end
  end
end

defmodule Workbench.Devtools.Overlay do
  @moduledoc "Builds a product-visible debug rail from runtime devtools data."

  alias Workbench.{Node, Style}
  alias Workbench.Widgets.Pane

  @spec title() :: String.t()
  def title, do: "Workbench Debug Rail"

  @spec node(map()) :: Workbench.Node.t()
  def node(devtools) when is_map(devtools) do
    latest = Map.get(devtools, :latest) || %{}

    Node.vstack(
      :workbench_debug_rail,
      [
        Pane.new(
          id: :debug_session,
          title: title(),
          lines: session_lines(devtools, latest)
        )
        |> Style.border_fg(:focus),
        Pane.new(
          id: :debug_events,
          title: "Recent Events",
          lines: recent_event_lines(devtools)
        )
        |> Style.border_fg(:warning),
        Pane.new(
          id: :debug_commands,
          title: "Recent Commands",
          lines: recent_command_lines(devtools)
        )
        |> Style.border_fg(:accent),
        Pane.new(
          id: :debug_runtime,
          title: "Runtime Summary",
          lines: runtime_lines(latest)
        )
        |> Style.border_fg(:success)
      ],
      constraints: [{:length, 7}, {:min, 6}, {:min, 5}, {:min, 8}]
    )
  end

  defp session_lines(devtools, latest) do
    [
      "debug: #{if(Map.get(devtools, :enabled?, false), do: "enabled", else: "disabled")}",
      "artifacts: #{Map.get(devtools, :artifact_dir, "none")}",
      "route: #{Map.get(latest, :route, "unknown")}",
      "viewport: #{format_viewport(Map.get(latest, :viewport))}",
      "sequence: #{Map.get(latest, :sequence, 0)}"
    ]
  end

  defp recent_event_lines(devtools) do
    devtools
    |> Map.get(:events, [])
    |> Enum.take(5)
    |> Enum.map(fn entry -> "##{entry.sequence} #{format_trigger(entry.trigger)}" end)
    |> case do
      [] -> ["No events captured yet."]
      lines -> lines
    end
  end

  defp recent_command_lines(devtools) do
    devtools
    |> Map.get(:commands, [])
    |> Enum.take(5)
    |> Enum.map(fn entry ->
      command_summary =
        entry
        |> Map.get(:commands, [])
        |> Enum.map_join(", ", &Map.get(&1, :kind, "unknown"))

      "##{entry.sequence} #{if(command_summary == "", do: "no commands", else: command_summary)}"
    end)
    |> case do
      [] -> ["No commands captured yet."]
      lines -> lines
    end
  end

  defp runtime_lines(latest) do
    component_paths =
      latest
      |> Map.get(:component_paths, [])
      |> Enum.take(4)
      |> case do
        [] -> ["components: none"]
        paths -> ["components: #{Enum.join(paths, " | ")}"]
      end

    [
      "render entries: #{Map.get(latest, :render_tree_entries, 0)}",
      "focus paths: #{Map.get(latest, :focus_count, 0)}",
      "regions: #{Map.get(latest, :region_count, 0)}",
      "subscriptions: #{Map.get(latest, :subscription_count, 0)}"
    ] ++ component_paths
  end

  defp format_trigger(%{kind: kind} = trigger) do
    case kind do
      :key ->
        "#{kind}: #{Map.get(trigger, :code)} #{inspect(Map.get(trigger, :modifiers, []))} -> #{Map.get(trigger, :resolved)}"

      :mouse ->
        "#{kind}: #{Map.get(trigger, :button, "mouse")} -> #{Map.get(trigger, :resolved)}"

      :resize ->
        "#{kind}: #{Map.get(trigger, :width)}x#{Map.get(trigger, :height)}"

      :info ->
        "#{kind}: #{Map.get(trigger, :message)}"

      :init ->
        "#{kind}: #{Map.get(trigger, :module)}"

      other ->
        "#{other}: #{inspect(trigger)}"
    end
  end

  defp format_viewport(%{width: width, height: height}), do: "#{width}x#{height}"
  defp format_viewport(_other), do: "unknown"
end

defmodule Workbench.Devtools.Driver do
  @moduledoc """
  Deterministic reducer-runtime driver helpers for TUI automation.

  This is the first automation layer. It intentionally drives the reducer
  runtime through synthetic events and public snapshots instead of depending on
  PTY scraping.
  """

  alias ExRatatui.{Event, Runtime}

  @spec snapshot(GenServer.server()) :: map()
  def snapshot(server), do: Runtime.snapshot(server)

  @spec debug_snapshot(GenServer.server(), timeout()) :: map()
  def debug_snapshot(server, timeout_ms \\ 1_000) do
    send(server, {:workbench_devtools_snapshot_request, self()})

    receive do
      {:workbench_devtools_snapshot, snapshot} -> snapshot
    after
      timeout_ms -> raise "timed out waiting for workbench devtools snapshot"
    end
  end

  @spec inject_key(GenServer.server(), String.t(), [String.t()]) :: :ok
  def inject_key(server, code, modifiers \\ []) do
    Runtime.inject_event(server, %Event.Key{code: code, modifiers: modifiers, kind: "press"})
  end

  @spec inject_resize(GenServer.server(), non_neg_integer(), non_neg_integer()) :: :ok
  def inject_resize(server, width, height) do
    case Runtime.snapshot(server).transport do
      transport when transport in [:ssh, :distributed_server] ->
        send(server, {:ex_ratatui_resize, width, height})
        :ok

      _other ->
        Runtime.inject_event(server, %Event.Resize{width: width, height: height})
    end
  end

  @spec wait_for_snapshot!(
          GenServer.server(),
          String.t(),
          (map() -> as_boolean(term())),
          timeout()
        ) ::
          map()
  def wait_for_snapshot!(server, label, predicate, timeout_ms \\ 3_000)
      when is_function(predicate, 1) do
    wait_for!(fn -> snapshot(server) end, label, predicate, timeout_ms)
  end

  @spec wait_for_debug_snapshot!(
          GenServer.server(),
          String.t(),
          (map() -> as_boolean(term())),
          timeout()
        ) :: map()
  def wait_for_debug_snapshot!(server, label, predicate, timeout_ms \\ 3_000)
      when is_function(predicate, 1) do
    wait_for!(fn -> debug_snapshot(server) end, label, predicate, timeout_ms)
  end

  defp wait_for!(fetcher, label, predicate, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait_for(fetcher, label, predicate, deadline)
  end

  defp do_wait_for(fetcher, label, predicate, deadline) do
    snapshot = fetcher.()

    cond do
      predicate.(snapshot) ->
        snapshot

      System.monotonic_time(:millisecond) >= deadline ->
        raise "#{label} timed out waiting for snapshot condition. Last snapshot: #{inspect(snapshot)}"

      true ->
        Process.sleep(10)
        do_wait_for(fetcher, label, predicate, deadline)
    end
  end
end

defmodule Workbench.Devtools.RenderTree do
  @moduledoc false
  def from_snapshot(snapshot), do: Map.get(snapshot || %{}, :render_tree)
end

defmodule Workbench.Devtools.FocusTree do
  @moduledoc false
  def from_snapshot(snapshot), do: Map.get(snapshot || %{}, :focus_tree)
end

defmodule Workbench.Devtools.RegionMap do
  @moduledoc false
  def from_snapshot(snapshot), do: Map.get(snapshot || %{}, :region_map)
end

defmodule Workbench.Devtools.FocusTrace do
  @moduledoc false
  def entries(focus_tree), do: Map.get(focus_tree || %{}, :paths, [])
end

defmodule Workbench.Devtools.EventLog do
  @moduledoc false

  alias Workbench.Devtools.History

  @spec append([term()], term(), pos_integer()) :: [term()]
  def append(entries, event, limit \\ 50) do
    History.push(List.wrap(entries), event, limit)
  end
end

defmodule Workbench.Devtools.CommandTrace do
  @moduledoc false

  def summarize(commands) do
    commands
    |> List.wrap()
    |> Enum.map(&Map.get(&1, :kind, :unknown))
  end
end

defmodule Workbench.Devtools.RenderStats do
  @moduledoc false
  def from_tree(%{flat: flat}) when is_list(flat), do: %{entry_count: length(flat)}
  def from_tree(_other), do: %{entry_count: 0}
end

defmodule Workbench.Devtools.FileWatcher do
  @moduledoc false
  def enabled?, do: Code.ensure_loaded?(FileSystem)
end

defmodule Workbench.Devtools.HotReload do
  @moduledoc false
  def status, do: :planned
end
