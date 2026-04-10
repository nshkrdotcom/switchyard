defmodule Switchyard.Contracts.SiteDescriptor do
  @moduledoc "Descriptor for an installed site."

  alias Switchyard.Contracts

  @enforce_keys [:id, :title, :provider]
  defstruct id: nil,
            title: nil,
            provider: nil,
            kind: :local,
            environment: "default",
            capabilities: []

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          provider: module(),
          kind: atom(),
          environment: String.t(),
          capabilities: [atom()]
        }

  @spec new!(map()) :: t()
  def new!(attrs) do
    attrs = Contracts.fetch_required!(attrs, [:id, :title, :provider])
    struct!(__MODULE__, attrs)
  end
end
