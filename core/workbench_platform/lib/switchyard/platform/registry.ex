defmodule Switchyard.Platform.Registry do
  @moduledoc """
  Registry helpers for site provider modules.
  """

  alias Switchyard.Contracts.{Action, AppDescriptor, SiteDescriptor}
  alias Switchyard.Contracts.SiteProvider

  @spec sites([module()]) :: [SiteDescriptor.t()]
  def sites(site_modules) when is_list(site_modules) do
    Enum.map(site_modules, &site_definition!/1)
  end

  @spec site(String.t(), [module()]) :: SiteDescriptor.t() | nil
  def site(site_id, site_modules) when is_binary(site_id) do
    Enum.find_value(site_modules, fn module ->
      case site_definition!(module) do
        %SiteDescriptor{id: ^site_id} = descriptor -> descriptor
        _descriptor -> nil
      end
    end)
  end

  @spec apps(String.t(), [module()]) :: [AppDescriptor.t()]
  def apps(site_id, site_modules) when is_binary(site_id) do
    case provider(site_id, site_modules) do
      nil -> []
      module -> module.apps()
    end
  end

  @spec actions(String.t(), [module()]) :: [Action.t()]
  def actions(site_id, site_modules) when is_binary(site_id) do
    case provider(site_id, site_modules) do
      nil -> []
      module -> module.actions()
    end
  end

  @spec provider(String.t(), [module()]) :: module() | nil
  def provider(site_id, site_modules) when is_binary(site_id) do
    Enum.find(site_modules, fn module ->
      site_definition!(module).id == site_id
    end)
  end

  defp site_definition!(module) do
    case Code.ensure_loaded(module) do
      {:module, ^module} ->
        if function_exported?(module, :site_definition, 0) do
          module.site_definition()
        else
          raise ArgumentError, "#{inspect(module)} does not implement #{inspect(SiteProvider)}"
        end

      {:error, _reason} ->
        raise ArgumentError, "#{inspect(module)} could not be loaded"
    end
  end
end
