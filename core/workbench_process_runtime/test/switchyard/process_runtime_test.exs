defmodule Switchyard.ProcessRuntimeTest do
  use ExUnit.Case, async: true

  alias Switchyard.ProcessRuntime

  test "builds a process spec and previews the command" do
    spec = ProcessRuntime.spec!(%{id: "echo", command: "printf 'hello\\n'"})

    assert spec.id == "echo"
    assert ProcessRuntime.preview_command(spec) == "printf 'hello\\n'"
  end

  test "starts a managed process and forwards output and exit status" do
    spec = ProcessRuntime.spec!(%{id: "echo", command: "printf 'hello\\nworld\\n'"})

    assert {:ok, pid} = ProcessRuntime.start_managed(spec, self())
    assert is_pid(pid)

    assert_receive {:process_output, "echo", "hello"}
    assert_receive {:process_output, "echo", "world"}
    assert_receive {:process_exit, "echo", 0}
  end
end
