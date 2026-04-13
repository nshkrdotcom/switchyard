defmodule Switchyard.Platform do
  @moduledoc """
  Provider-driven platform catalog helpers.
  """

  alias Switchyard.Platform.Registry

  @spec catalog([module()]) :: %{sites: list(), apps: list(), actions: list()}
  def catalog(site_modules) when is_list(site_modules) do
    sites = Registry.sites(site_modules)

    %{
      sites: sites,
      apps: Enum.flat_map(sites, fn site -> Registry.apps(site.id, site_modules) end),
      actions: Enum.flat_map(sites, fn site -> Registry.actions(site.id, site_modules) end)
    }
  end
end
