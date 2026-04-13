defmodule Switchyard.Contracts.Job do
  @moduledoc "Typed job contract."

  alias Switchyard.Contracts

  @enforce_keys [:id, :kind, :title, :status]
  defstruct id: nil,
            kind: nil,
            title: nil,
            status: nil,
            progress: %{current: 0, total: 0},
            started_at: nil,
            finished_at: nil,
            related_resources: []

  @type t :: %__MODULE__{
          id: String.t(),
          kind: atom(),
          title: String.t(),
          status: atom(),
          progress: %{current: non_neg_integer(), total: non_neg_integer()},
          started_at: DateTime.t() | nil,
          finished_at: DateTime.t() | nil,
          related_resources: [term()]
        }

  @spec new!(map()) :: t()
  def new!(attrs) do
    attrs = Contracts.fetch_required!(attrs, [:id, :kind, :title, :status])
    struct!(__MODULE__, attrs)
  end
end
