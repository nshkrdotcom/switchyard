defmodule Switchyard.LogRuntime do
  @moduledoc """
  Pure helpers for bounded log retention and filtering.
  """

  alias Switchyard.Contracts.LogEvent

  defmodule Buffer do
    @moduledoc "Bounded in-memory log buffer."

    @enforce_keys [:max_entries]
    defstruct max_entries: 50, entries: []

    @type t :: %__MODULE__{
            max_entries: pos_integer(),
            entries: [LogEvent.t()]
          }
  end

  @spec new_buffer(pos_integer()) :: Buffer.t()
  def new_buffer(max_entries) when is_integer(max_entries) and max_entries > 0 do
    %Buffer{max_entries: max_entries}
  end

  @spec append(Buffer.t(), LogEvent.t()) :: Buffer.t()
  def append(%Buffer{} = buffer, %LogEvent{} = event) do
    entries =
      [event | buffer.entries]
      |> Enum.take(buffer.max_entries)

    %{buffer | entries: entries}
  end

  @spec recent(Buffer.t()) :: [LogEvent.t()]
  def recent(%Buffer{} = buffer) do
    Enum.reverse(buffer.entries)
  end

  @spec filter(Buffer.t(), keyword()) :: [LogEvent.t()]
  def filter(%Buffer{} = buffer, opts) when is_list(opts) do
    level = Keyword.get(opts, :level)
    source_kind = Keyword.get(opts, :source_kind)

    buffer
    |> recent()
    |> Enum.filter(fn event ->
      match_level?(event, level) and match_source_kind?(event, source_kind)
    end)
  end

  defp match_level?(_event, nil), do: true
  defp match_level?(event, level), do: event.level == level

  defp match_source_kind?(_event, nil), do: true
  defp match_source_kind?(event, source_kind), do: event.source_kind == source_kind
end
