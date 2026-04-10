defmodule Switchyard.Contracts.StreamDescriptor do
  @moduledoc "Descriptor for a live stream."

  alias Switchyard.Contracts

  @enforce_keys [:id, :kind, :subject]
  defstruct id: nil, kind: nil, subject: nil, retention: :bounded, capabilities: []

  @type t :: %__MODULE__{
          id: String.t(),
          kind: atom(),
          subject: term(),
          retention: atom(),
          capabilities: [atom()]
        }

  @spec new!(map()) :: t()
  def new!(attrs) do
    attrs = Contracts.fetch_required!(attrs, [:id, :kind, :subject])
    struct!(__MODULE__, attrs)
  end
end
