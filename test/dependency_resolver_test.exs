Code.require_file("../build_support/dependency_resolver.exs", __DIR__)

defmodule Switchyard.Build.DependencyResolverTest do
  use ExUnit.Case, async: false

  alias Switchyard.Build.DependencyResolver

  setup do
    original = System.get_env("EX_RATATUI_PATH")

    on_exit(fn ->
      case original do
        nil -> System.delete_env("EX_RATATUI_PATH")
        value -> System.put_env("EX_RATATUI_PATH", value)
      end
    end)
  end

  test "returns a valid git dependency tuple when the local ex_ratatui checkout is disabled" do
    System.put_env("EX_RATATUI_PATH", "disabled")

    assert DependencyResolver.ex_ratatui() ==
             {:ex_ratatui,
              [github: "nshkrdotcom/ex_ratatui", ref: "abb502870942e1842a4b93d5ad32cd85030bfd00"]}
  end

  test "merges dependency opts into the fallback git dependency tuple" do
    System.put_env("EX_RATATUI_PATH", "disabled")

    assert DependencyResolver.ex_ratatui(runtime: false) ==
             {:ex_ratatui,
              [
                github: "nshkrdotcom/ex_ratatui",
                ref: "abb502870942e1842a4b93d5ad32cd85030bfd00",
                runtime: false
              ]}
  end

  test "prefers an explicit local checkout path when provided" do
    path = Path.join(System.tmp_dir!(), "switchyard_dependency_resolver_ex_ratatui")
    File.mkdir_p!(path)
    System.put_env("EX_RATATUI_PATH", path)

    assert DependencyResolver.ex_ratatui(runtime: false) ==
             {:ex_ratatui, [path: path, runtime: false]}
  end
end
