Code.require_file("../build_support/dependency_resolver.exs", __DIR__)

defmodule Switchyard.Build.DependencyResolverTest do
  use ExUnit.Case, async: false

  alias Switchyard.Build.DependencyResolver

  test "prefers WELD_PATH over git and hex" do
    with_env(
      %{
        "WELD_PATH" => "../weld",
        "WELD_GIT_REF" => "deadbeef",
        "WELD_GIT_URL" => "https://example.test/ignored/weld.git"
      },
      fn ->
        assert {:weld, opts} = DependencyResolver.weld()

        assert Keyword.fetch!(opts, :path) ==
                 Path.expand("../weld", DependencyResolver.repo_root())

        refute Keyword.has_key?(opts, :git)
        refute Keyword.has_key?(opts, :ref)
      end
    )
  end

  test "uses the canonical weld git URL when only a ref is set" do
    with_env(
      %{
        "WELD_PATH" => "disabled",
        "WELD_GIT_REF" => "773ba79",
        "WELD_GIT_URL" => nil
      },
      fn ->
        assert {:weld, opts} = DependencyResolver.weld()

        assert Keyword.fetch!(opts, :git) == "https://github.com/nshkrdotcom/weld.git"
        assert Keyword.fetch!(opts, :ref) == "773ba79"
        refute Keyword.has_key?(opts, :path)
      end
    )
  end

  test "supports explicit weld git URLs" do
    with_env(
      %{
        "WELD_PATH" => "disabled",
        "WELD_GIT_REF" => "feedface",
        "WELD_GIT_URL" => "https://example.test/custom/weld.git"
      },
      fn ->
        assert {:weld, opts} = DependencyResolver.weld()

        assert Keyword.fetch!(opts, :git) == "https://example.test/custom/weld.git"
        assert Keyword.fetch!(opts, :ref) == "feedface"
        refute Keyword.has_key?(opts, :path)
      end
    )
  end

  test "falls back to Hex when weld overrides are disabled" do
    with_env(
      %{
        "WELD_PATH" => "disabled",
        "WELD_GIT_REF" => "disabled",
        "WELD_GIT_URL" => "disabled"
      },
      fn ->
        assert {:weld, requirement, opts} = DependencyResolver.weld()
        assert requirement == "~> 0.6.0"
        refute Keyword.has_key?(opts, :path)
        refute Keyword.has_key?(opts, :git)
        refute Keyword.has_key?(opts, :ref)
      end
    )
  end

  test "returns a Hex dependency tuple for ex_ratatui" do
    assert DependencyResolver.ex_ratatui() == {:ex_ratatui, "~> 0.7.0", []}
  end

  test "merges dependency opts into the Hex dependency tuple" do
    assert DependencyResolver.ex_ratatui(runtime: false) ==
             {:ex_ratatui, "~> 0.7.0", runtime: false}
  end

  defp with_env(overrides, fun) when is_map(overrides) and is_function(fun, 0) do
    previous =
      for {key, _value} <- overrides, into: %{} do
        {key, System.get_env(key)}
      end

    Enum.each(overrides, fn
      {key, nil} -> System.delete_env(key)
      {key, value} -> System.put_env(key, value)
    end)

    try do
      fun.()
    after
      Enum.each(previous, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end
  end
end
