defmodule Switchyard.Contracts.AppProvider do
  @moduledoc "Behaviour for site-contributed apps."

  alias Switchyard.Contracts.{AppDescriptor, Resource, ResourceDetail}

  @callback app_definition() :: AppDescriptor.t()
  @callback list(map()) :: [Resource.t()]
  @callback detail(Resource.t(), map()) :: ResourceDetail.t()
end
