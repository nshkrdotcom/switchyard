defmodule Switchyard.Contracts.SiteProvider do
  @moduledoc "Behaviour for installed site providers."

  alias Switchyard.Contracts.{
    Action,
    ActionResult,
    AppDescriptor,
    Resource,
    ResourceDetail,
    SiteDescriptor
  }

  @callback site_definition() :: SiteDescriptor.t()
  @callback apps() :: [AppDescriptor.t()]
  @callback actions() :: [Action.t()]
  @callback resources(map()) :: [Resource.t()]
  @callback detail(Resource.t(), map()) :: ResourceDetail.t()
  @callback execute_action(String.t(), map(), map()) :: {:ok, ActionResult.t()} | {:error, term()}

  @optional_callbacks execute_action: 3
end
