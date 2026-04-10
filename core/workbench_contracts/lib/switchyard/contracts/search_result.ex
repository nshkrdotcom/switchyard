defmodule Switchyard.Contracts.SearchResult do
  @moduledoc "Typed search result contract."

  alias Switchyard.Contracts

  @enforce_keys [:id, :kind, :title, :action, :score]
  defstruct id: nil, kind: nil, title: nil, subtitle: nil, action: nil, score: 0.0

  @type t :: %__MODULE__{
          id: String.t(),
          kind: atom(),
          title: String.t(),
          subtitle: String.t() | nil,
          action: term(),
          score: float()
        }

  @spec new!(map()) :: t()
  def new!(attrs) do
    attrs = Contracts.fetch_required!(attrs, [:id, :kind, :title, :action, :score])
    struct!(__MODULE__, attrs)
  end
end
