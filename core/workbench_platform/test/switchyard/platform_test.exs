defmodule Switchyard.PlatformTest do
  use ExUnit.Case, async: true

  alias Switchyard.Contracts.{Action, AppDescriptor, SiteDescriptor}
  alias Switchyard.Platform
  alias Switchyard.Platform.Registry

  defmodule FakeLocalSite do
    def site_definition do
      SiteDescriptor.new!(%{id: "local", title: "Local", provider: __MODULE__})
    end

    def apps do
      [
        AppDescriptor.new!(%{
          id: "local.processes",
          site_id: "local",
          title: "Processes",
          provider: __MODULE__
        })
      ]
    end

    def actions do
      [
        Action.new!(%{
          id: "local.process.start",
          title: "Start process",
          scope: {:site, "local"},
          provider: __MODULE__
        })
      ]
    end
  end

  defmodule FakeRemoteSite do
    def site_definition do
      SiteDescriptor.new!(%{id: "remote", title: "Remote", provider: __MODULE__})
    end

    def apps do
      [
        AppDescriptor.new!(%{
          id: "remote.workspaces",
          site_id: "remote",
          title: "Workspaces",
          provider: __MODULE__
        })
      ]
    end

    def actions do
      [
        Action.new!(%{
          id: "remote.workspace.open",
          title: "Open workspace",
          scope: {:site, "remote"},
          provider: __MODULE__
        })
      ]
    end
  end

  @providers [FakeLocalSite, FakeRemoteSite]

  test "lists sites and provider lookups" do
    assert [%SiteDescriptor{id: "local"}, %SiteDescriptor{id: "remote"}] =
             Registry.sites(@providers)

    assert %SiteDescriptor{id: "remote"} = Registry.site("remote", @providers)
    assert Registry.provider("missing", @providers) == nil
  end

  test "lists apps and actions by site id" do
    assert [%AppDescriptor{id: "local.processes"}] = Registry.apps("local", @providers)
    assert [%Action{id: "remote.workspace.open"}] = Registry.actions("remote", @providers)
  end

  test "builds a flat catalog" do
    catalog = Platform.catalog(@providers)

    assert length(catalog.sites) == 2
    assert Enum.any?(catalog.apps, &(&1.id == "remote.workspaces"))
    assert Enum.any?(catalog.actions, &(&1.id == "local.process.start"))
  end
end
