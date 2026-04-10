defmodule Switchyard.Contracts.AppDescriptor do
  @moduledoc "Descriptor for an app mounted under a site."

  alias Switchyard.Contracts

  @enforce_keys [:id, :site_id, :title, :provider]
  defstruct id: nil,
            site_id: nil,
            title: nil,
            provider: nil,
            resource_kinds: [],
            route_kind: :list

  @type t :: %__MODULE__{
          id: String.t(),
          site_id: String.t(),
          title: String.t(),
          provider: module(),
          resource_kinds: [atom()],
          route_kind: atom()
        }

  @spec new!(map()) :: t()
  def new!(attrs) do
    attrs = Contracts.fetch_required!(attrs, [:id, :site_id, :title, :provider])
    struct!(__MODULE__, attrs)
  end
end
