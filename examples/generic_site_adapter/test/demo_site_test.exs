defmodule GenericSiteAdapter.DemoSiteTest do
  use ExUnit.Case, async: true

  alias GenericSiteAdapter.DemoSite
  alias Switchyard.Platform

  test "external provider contributes catalog, resources, details, and actions" do
    catalog = Platform.catalog([DemoSite])

    assert [%{id: "generic_demo"}] = catalog.sites
    assert [%{id: "generic_demo.widgets"}] = catalog.apps
    assert [%{id: "generic_demo.widgets.refresh"}] = catalog.actions

    [resource | _rest] = DemoSite.resources(%{})
    assert resource.kind == :widget
    assert resource.site_id == "generic_demo"

    detail = DemoSite.detail(resource, %{})
    assert detail.resource.id == resource.id
    assert [%{title: "Widget"}] = detail.sections
    assert "Refresh widgets" in detail.recommended_actions
  end
end
