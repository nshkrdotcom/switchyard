defmodule Switchyard.Contracts.Resource do
  @moduledoc "Typed resource envelope used by shell and CLI surfaces."

  alias Switchyard.Contracts

  @enforce_keys [:site_id, :kind, :id, :title]
  defstruct site_id: nil,
            kind: nil,
            id: nil,
            title: nil,
            subtitle: nil,
            status: :unknown,
            tags: [],
            summary: nil,
            capabilities: [],
            ext: %{}

  @type t :: %__MODULE__{
          site_id: String.t(),
          kind: atom(),
          id: String.t(),
          title: String.t(),
          subtitle: String.t() | nil,
          status: atom(),
          tags: [atom()],
          summary: String.t() | nil,
          capabilities: [atom()],
          ext: map()
        }

  @spec new!(map()) :: t()
  def new!(attrs) do
    attrs = Contracts.fetch_required!(attrs, [:site_id, :kind, :id, :title])
    struct!(__MODULE__, attrs)
  end
end
