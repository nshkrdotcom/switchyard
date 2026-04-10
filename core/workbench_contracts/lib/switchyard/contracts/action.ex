defmodule Switchyard.Contracts.Action do
  @moduledoc "Typed action contract."

  alias Switchyard.Contracts

  @enforce_keys [:id, :title, :scope, :provider]
  defstruct id: nil,
            title: nil,
            scope: nil,
            provider: nil,
            input_schema: %{},
            confirmation: :never

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          scope: term(),
          provider: module(),
          input_schema: map(),
          confirmation: atom()
        }

  @spec new!(map()) :: t()
  def new!(attrs) do
    attrs = Contracts.fetch_required!(attrs, [:id, :title, :scope, :provider])
    struct!(__MODULE__, attrs)
  end
end
