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

  defmodule FakeJidoSite do
    def site_definition do
      SiteDescriptor.new!(%{id: "jido-hive", title: "Jido Hive", provider: __MODULE__})
    end

    def apps do
      [
        AppDescriptor.new!(%{
          id: "jido-hive.rooms",
          site_id: "jido-hive",
          title: "Rooms",
          provider: __MODULE__
        })
      ]
    end

    def actions do
      [
        Action.new!(%{
          id: "jido-hive.room.run",
          title: "Run room",
          scope: {:site, "jido-hive"},
          provider: __MODULE__
        })
      ]
    end
  end

  @providers [FakeLocalSite, FakeJidoSite]

  test "lists sites and provider lookups" do
    assert [%SiteDescriptor{id: "local"}, %SiteDescriptor{id: "jido-hive"}] =
             Registry.sites(@providers)

    assert %SiteDescriptor{id: "jido-hive"} = Registry.site("jido-hive", @providers)
    assert Registry.provider("missing", @providers) == nil
  end

  test "lists apps and actions by site id" do
    assert [%AppDescriptor{id: "local.processes"}] = Registry.apps("local", @providers)
    assert [%Action{id: "jido-hive.room.run"}] = Registry.actions("jido-hive", @providers)
  end

  test "builds a flat catalog" do
    catalog = Platform.catalog(@providers)

    assert length(catalog.sites) == 2
    assert Enum.any?(catalog.apps, &(&1.id == "jido-hive.rooms"))
    assert Enum.any?(catalog.actions, &(&1.id == "local.process.start"))
  end
end
