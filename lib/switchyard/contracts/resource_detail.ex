defmodule Switchyard.Contracts.ResourceDetail do
  @moduledoc "Structured detail payload for a resource."

  alias Switchyard.Contracts
  alias Switchyard.Contracts.Resource

  @enforce_keys [:resource]
  defstruct resource: nil, sections: [], recommended_actions: []

  @type section :: %{title: String.t(), lines: [String.t()]}

  @type t :: %__MODULE__{
          resource: Resource.t(),
          sections: [section()],
          recommended_actions: [String.t()]
        }

  @spec new!(map()) :: t()
  def new!(attrs) do
    attrs = Contracts.fetch_required!(attrs, [:resource])
    struct!(__MODULE__, attrs)
  end
end
