defmodule Switchyard.PlatformTest do
  use ExUnit.Case, async: true

  alias Switchyard.Contracts.{Action, AppDescriptor, Resource, SiteDescriptor}
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
        }),
        Action.new!(%{
          id: "shared.process.stop",
          title: "Stop process",
          scope: {:resource, :process},
          provider: __MODULE__
        }),
        Action.new!(%{
          id: "local.process.inspect-special",
          title: "Inspect special process",
          scope: {:resource_instance, "local", :process, "proc-special"},
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

  defmodule FakeMalformedActionSite do
    def site_definition do
      SiteDescriptor.new!(%{id: "malformed", title: "Malformed", provider: __MODULE__})
    end

    def apps, do: []

    def actions, do: [%{id: "malformed.action"}]
  end

  defmodule FakeDuplicateActionSite do
    def site_definition do
      SiteDescriptor.new!(%{id: "duplicate", title: "Duplicate", provider: __MODULE__})
    end

    def apps, do: []

    def actions do
      [
        Action.new!(%{
          id: "local.process.start",
          title: "Duplicate start process",
          scope: {:site, "duplicate"},
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

    assert [
             %Action{id: "local.process.start"},
             %Action{id: "shared.process.stop"},
             %Action{id: "local.process.inspect-special"}
           ] = Registry.actions("local", @providers)
  end

  test "lists all actions across providers" do
    assert [
             "local.process.inspect-special",
             "local.process.start",
             "remote.workspace.open",
             "shared.process.stop"
           ] = @providers |> Registry.actions() |> Enum.map(& &1.id) |> Enum.sort()
  end

  test "fetches an action by id" do
    assert {:ok, %Action{id: "remote.workspace.open", provider: FakeRemoteSite}} =
             Registry.fetch_action("remote.workspace.open", @providers)

    assert :error = Registry.fetch_action("missing.action", @providers)
  end

  test "filters actions by resource kind and resource instance" do
    process =
      Resource.new!(%{
        site_id: "local",
        kind: :process,
        id: "proc-special",
        title: "Special process"
      })

    workspace =
      Resource.new!(%{
        site_id: "remote",
        kind: :workspace,
        id: "workspace-1",
        title: "Workspace"
      })

    assert [
             "local.process.inspect-special",
             "shared.process.stop"
           ] =
             process
             |> Registry.actions_for_resource(@providers)
             |> Enum.map(& &1.id)
             |> Enum.sort()

    assert [] = Registry.actions_for_resource(workspace, @providers)
  end

  test "rejects malformed action definitions" do
    error =
      assert_raise ArgumentError, fn ->
        Registry.actions([FakeMalformedActionSite])
      end

    assert Exception.message(error) =~ "action definitions"
  end

  test "rejects duplicate action ids" do
    error =
      assert_raise ArgumentError, fn ->
        Registry.actions([FakeLocalSite, FakeDuplicateActionSite])
      end

    assert Exception.message(error) =~ "duplicate action id"
  end

  test "builds a flat catalog" do
    catalog = Platform.catalog(@providers)

    assert length(catalog.sites) == 2
    assert Enum.any?(catalog.apps, &(&1.id == "remote.workspaces"))
    assert Enum.any?(catalog.actions, &(&1.id == "local.process.start"))
  end
end
