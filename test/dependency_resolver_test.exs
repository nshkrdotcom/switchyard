Code.require_file("../build_support/dependency_resolver.exs", __DIR__)

defmodule Switchyard.Build.DependencyResolverTest do
  use ExUnit.Case, async: false

  alias Switchyard.Build.DependencyResolver

  test "returns a Hex dependency tuple for ex_ratatui" do
    assert DependencyResolver.ex_ratatui() == {:ex_ratatui, "~> 0.7.0", []}
  end

  test "merges dependency opts into the Hex dependency tuple" do
    assert DependencyResolver.ex_ratatui(runtime: false) ==
             {:ex_ratatui, "~> 0.7.0", runtime: false}
  end
end
