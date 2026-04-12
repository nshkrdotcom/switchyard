defmodule Switchyard.TUITest do
  use ExUnit.Case, async: true

  alias Switchyard.Contracts.{AppDescriptor, Resource, ResourceDetail, SiteDescriptor}
  alias Switchyard.TUI
  alias Switchyard.TUI.State

  defmodule ExampleSite do
    @behaviour Switchyard.Contracts.SiteProvider

    @impl true
    def site_definition do
      SiteDescriptor.new!(%{
        id: "example",
        title: "Example",
        provider: __MODULE__,
        kind: :remote
      })
    end

    @impl true
    def apps do
      [
        AppDescriptor.new!(%{
          id: "example.notes",
          site_id: "example",
          title: "Notes",
          provider: __MODULE__,
          resource_kinds: [:note],
          route_kind: :list_detail
        })
      ]
    end

    @impl true
    def actions, do: []

    @impl true
    def resources(_snapshot) do
      [
        Resource.new!(%{
          site_id: "example",
          kind: :note,
          id: "note-1",
          title: "First note",
          subtitle: "ready",
          status: :ready,
          summary: "example summary"
        }),
        Resource.new!(%{
          site_id: "example",
          kind: :job,
          id: "job-1",
          title: "Ignored job",
          subtitle: "queued",
          status: :queued,
          summary: "should be filtered"
        })
      ]
    end

    @impl true
    def detail(resource, _snapshot) do
      ResourceDetail.new!(%{
        resource: resource,
        sections: [%{title: "Detail", lines: ["id: #{resource.id}"]}],
        recommended_actions: ["Inspect"]
      })
    end
  end

  test "exposes the initial shell state" do
    assert %{route: :home} = TUI.initial_shell_state()
  end

  test "tracks site selection and filters resources by app kind" do
    apps = ExampleSite.apps()

    state =
      State.new(
        sites: [%{id: "local", title: "Local"}, %{id: "example", title: "Example"}],
        apps: apps,
        snapshot: %{processes: [], jobs: []},
        home_cursor: 1,
        shell: %{
          State.new().shell
          | selected_site_id: "example",
            selected_app_id: "example.notes"
        }
      )

    assert State.selected_home_site(state).id == "example"
    assert State.selected_site_app(state).id == "example.notes"
    assert [%{id: "note-1"}] = State.resources_for_selected_app(state)
  end
end
