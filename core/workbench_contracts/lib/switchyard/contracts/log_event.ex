defmodule Switchyard.Contracts.LogEvent do
  @moduledoc "Normalized log event contract."

  alias Switchyard.Contracts

  @enforce_keys [:at, :level, :source_kind, :source_id, :stream_id, :message]
  defstruct at: nil,
            level: nil,
            source_kind: nil,
            source_id: nil,
            stream_id: nil,
            message: nil,
            fields: %{}

  @type t :: %__MODULE__{
          at: DateTime.t(),
          level: atom(),
          source_kind: atom(),
          source_id: String.t(),
          stream_id: String.t(),
          message: String.t(),
          fields: map()
        }

  @spec new!(map()) :: t()
  def new!(attrs) do
    attrs =
      Contracts.fetch_required!(attrs, [
        :at,
        :level,
        :source_kind,
        :source_id,
        :stream_id,
        :message
      ])

    struct!(__MODULE__, attrs)
  end
end
