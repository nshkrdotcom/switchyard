defmodule Switchyard.LogRuntimeTest do
  use ExUnit.Case, async: true

  alias Switchyard.Contracts.LogEvent
  alias Switchyard.LogRuntime

  test "retains only the newest entries up to the configured maximum" do
    buffer =
      1..4
      |> Enum.map(fn index ->
        LogEvent.new!(%{
          at: DateTime.utc_now(),
          level: :info,
          source_kind: :process,
          source_id: "proc",
          stream_id: "logs/proc",
          message: "line-#{index}"
        })
      end)
      |> Enum.reduce(LogRuntime.new_buffer(3), &LogRuntime.append(&2, &1))

    assert Enum.map(LogRuntime.recent(buffer), & &1.message) == ["line-2", "line-3", "line-4"]
  end

  test "filters by level and source kind" do
    info =
      LogEvent.new!(%{
        at: DateTime.utc_now(),
        level: :info,
        source_kind: :process,
        source_id: "proc",
        stream_id: "logs/proc",
        message: "info"
      })

    error =
      LogEvent.new!(%{
        at: DateTime.utc_now(),
        level: :error,
        source_kind: :job,
        source_id: "job-1",
        stream_id: "logs/job-1",
        message: "error"
      })

    buffer =
      LogRuntime.new_buffer(10)
      |> LogRuntime.append(info)
      |> LogRuntime.append(error)

    assert [%LogEvent{message: "error"}] = LogRuntime.filter(buffer, level: :error)
    assert [%LogEvent{message: "info"}] = LogRuntime.filter(buffer, source_kind: :process)
  end
end
