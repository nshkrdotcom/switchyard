defmodule Switchyard.WeldContractTest do
  use ExUnit.Case, async: true

  @manifest_path Path.expand("../build_support/weld.exs", __DIR__)

  test "Weld dependencies preserve source package roots" do
    {manifest, _binding} = Code.eval_file(@manifest_path)
    dependencies = Keyword.fetch!(manifest, :dependencies)

    execution_plane = dependency_opts(dependencies, :execution_plane)
    assert execution_plane[:subdir] == "core/execution_plane"
    assert execution_plane[:override] == true
    refute Keyword.has_key?(execution_plane, :sparse)

    process_runtime = dependency_opts(dependencies, :execution_plane_process)
    assert process_runtime[:subdir] == "runtimes/execution_plane_process"
    refute Keyword.has_key?(process_runtime, :sparse)

    operator_terminal = dependency_opts(dependencies, :execution_plane_operator_terminal)
    assert operator_terminal[:subdir] == "runtimes/execution_plane_operator_terminal"
    refute Keyword.has_key?(operator_terminal, :sparse)
  end

  defp dependency_opts(dependencies, app) do
    dependencies
    |> Keyword.fetch!(app)
    |> Keyword.fetch!(:opts)
  end
end
