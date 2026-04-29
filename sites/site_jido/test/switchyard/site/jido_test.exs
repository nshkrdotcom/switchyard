defmodule Switchyard.Site.JidoTest do
  use ExUnit.Case, async: true

  alias Switchyard.Contracts.{Resource, SearchResult, SiteDescriptor}
  alias Switchyard.Site.Jido

  @snapshot %{
    runs: [
      %{
        id: "run-1",
        capability_id: "codex.exec",
        runtime_class: "session",
        status: "completed",
        target_id: "target-1",
        tenant_id: "tenant-1",
        policy: %{"max_runtime_ms" => 5_000, "token" => "secret-token"},
        stream_ids: ["jido/run-1/events"]
      }
    ],
    boundary_sessions: [
      %{
        id: "boundary-1",
        status: "attached",
        owner_id: "operator-1",
        route_id: "route-1",
        target_id: "target-1",
        attach_grant_id: "grant-1",
        expires_at: "2026-04-28T12:00:00Z",
        policy: %{"mode" => "read_only"}
      }
    ],
    attach_grants: [
      %{
        id: "grant-1",
        status: "issued",
        boundary_session_id: "boundary-1",
        route_id: "route-1",
        subject_id: "run-1",
        target_id: "target-1",
        lease_id: "lease-1",
        allowed_operations: ["attach", "inspect"]
      }
    ]
  }

  test "site definition and apps describe the durable jido surface" do
    assert %SiteDescriptor{id: "jido", kind: :service} = Jido.site_definition()

    assert Enum.map(Jido.apps(), & &1.id) == [
             "jido.runs",
             "jido.boundary_sessions",
             "jido.attach_grants"
           ]
  end

  test "resources and detail render durable run state" do
    resources = Jido.resources(@snapshot)

    assert Enum.any?(resources, &match?(%Resource{id: "run-1", kind: :run}, &1))
    assert Enum.any?(resources, &match?(%Resource{id: "boundary-1", kind: :boundary_session}, &1))
    assert Enum.any?(resources, &match?(%Resource{id: "grant-1", kind: :attach_grant}, &1))

    detail =
      resources
      |> Enum.find(&(&1.id == "run-1"))
      |> then(&Jido.detail(&1, @snapshot))

    lines = detail_lines(detail)

    assert lines =~ "codex.exec"
    assert lines =~ "streams: jido/run-1/events"
    assert lines =~ "policy:"
    refute lines =~ "secret-token"
  end

  test "boundary session and attach grant details expose lease and routing context" do
    resources = Jido.resources(@snapshot)

    boundary_detail =
      resources
      |> Enum.find(&(&1.id == "boundary-1"))
      |> Jido.detail(@snapshot)

    assert detail_lines(boundary_detail) =~ "owner: operator-1"
    assert detail_lines(boundary_detail) =~ "expires_at: 2026-04-28T12:00:00Z"

    grant_detail =
      resources
      |> Enum.find(&(&1.id == "grant-1"))
      |> Jido.detail(@snapshot)

    assert detail_lines(grant_detail) =~ "lease: lease-1"
    assert detail_lines(grant_detail) =~ "allowed_operations: attach, inspect"
    assert detail_lines(grant_detail) =~ "target: target-1"
  end

  test "empty unavailable degraded and error states are explicit resources" do
    assert [%Resource{kind: :site_state, status: :empty, title: "Jido empty"}] =
             Jido.resources(%{runs: [], boundary_sessions: [], attach_grants: []})

    for status <- [:unavailable, :degraded, :error] do
      resources =
        Jido.resources(%{
          site_states: %{
            "jido" => %{status: status, message: "durable store #{status}"}
          }
        })

      assert [%Resource{kind: :site_state, status: ^status}] = resources
      assert hd(resources).summary == "durable store #{status}"
    end
  end

  test "search returns typed Jido results without secret metadata" do
    assert [%SearchResult{} | _] = results = Jido.search("run-1", @snapshot)

    assert Enum.any?(results, &(&1.action == {:open_resource, {"jido", :run, "run-1"}}))

    refute results
           |> Enum.map_join("\n", &inspect/1)
           |> String.contains?("secret-token")
  end

  defp detail_lines(detail) do
    detail.sections
    |> Enum.flat_map(& &1.lines)
    |> Enum.join("\n")
  end
end
