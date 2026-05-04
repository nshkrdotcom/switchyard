defmodule Switchyard.Contracts.GovernedRouteAuthorityTest do
  use ExUnit.Case, async: true

  alias Switchyard.Contracts.GovernedRouteAuthority

  test "materializes process routing, env, and operator transport from authority" do
    authority =
      GovernedRouteAuthority.new!(%{
        "authority_ref" => "authority-switchyard-1",
        "route_id" => "route-1",
        "provider_id" => "execution_plane",
        "target_id" => "target-1",
        "credential_ref" => %{"id" => "credential-1"},
        "env" => %{"SECRET_TOKEN" => "governed-secret"},
        "clear_env?" => true,
        "execution_surface" => %{
          "surface_kind" => "ssh_exec",
          "target_id" => "target-1",
          "transport_options" => %{"user" => "deploy"}
        },
        "operator_transport" => %{
          "transport" => "ssh",
          "port" => 3022,
          "auth_methods" => "password"
        }
      })

    assert authority.authority_ref == "authority-switchyard-1"
    assert authority.route_id == "route-1"
    assert authority.provider_id == "execution_plane"
    assert authority.target_id == "target-1"
    assert authority.credential_ref == %{"id" => "credential-1"}
    assert authority.env == %{"SECRET_TOKEN" => "governed-secret"}

    assert GovernedRouteAuthority.process_attrs(authority) == %{
             authority_ref: "authority-switchyard-1",
             clear_env?: true,
             env: %{"SECRET_TOKEN" => "governed-secret"},
             execution_surface: %{
               "surface_kind" => "ssh_exec",
               "target_id" => "target-1",
               "transport_options" => %{"user" => "deploy"}
             }
           }

    operator_opts = GovernedRouteAuthority.operator_terminal_opts(authority)
    assert Keyword.get(operator_opts, :transport) == :ssh
    assert Keyword.get(operator_opts, :port) == 3022
    assert Keyword.get(operator_opts, :auth_methods) == ~c"password"
  end

  test "rejects unknown operator transport keys without atomizing them" do
    assert {:error, {:invalid_operator_transport_key, "unexpected_key"}} =
             GovernedRouteAuthority.new(%{
               authority_ref: "authority-switchyard-1",
               operator_transport: %{"unexpected_key" => "value"}
             })
  end
end
