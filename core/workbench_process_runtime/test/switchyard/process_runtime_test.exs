defmodule Switchyard.ProcessRuntimeTest do
  use ExUnit.Case, async: true

  alias Switchyard.ProcessRuntime

  test "builds a default local spec with explicit execution metadata" do
    assert {:ok, spec} = ProcessRuntime.spec(%{id: "echo", command: "printf 'hello\\n'"})

    assert spec.id == "echo"
    assert spec.execution_surface.surface_kind == :local_subprocess
    assert spec.sandbox.mode == :inherit
    assert ProcessRuntime.preview_command(spec) =~ "printf 'hello\\n'"
  end

  test "normalizes execution surface fields from maps" do
    assert {:ok, spec} =
             ProcessRuntime.spec(%{
               id: "remote",
               command: "hostname",
               execution_surface: %{
                 "surface_kind" => "ssh_exec",
                 "target_id" => "demo.internal",
                 "transport_options" => %{"port" => 2222, "user" => "deploy"}
               }
             })

    assert spec.execution_surface.surface_kind == :ssh_exec
    assert spec.execution_surface.target_id == "demo.internal"
    assert spec.execution_surface.transport_options[:port] == 2222
    assert spec.execution_surface.transport_options[:ssh_user] == "deploy"
  end

  test "normalizes local execution surface strings from CLI specs" do
    assert {:ok, spec} =
             ProcessRuntime.spec(%{
               id: "local",
               command: "hostname",
               execution_surface: %{"surface_kind" => "local_subprocess"}
             })

    assert spec.execution_surface.surface_kind == :local_subprocess
  end

  test "rejects forbidden transport options on the execution surface" do
    assert {:error, {:forbidden_transport_option, :cwd}} =
             ProcessRuntime.spec(%{
               id: "bad",
               command: "hostname",
               execution_surface: %{surface_kind: :ssh_exec, transport_options: [cwd: "/tmp"]}
             })
  end

  test "rejects invalid sandbox command prefixes" do
    assert {:error, {:invalid_command_prefix, [:bad]}} =
             ProcessRuntime.spec(%{
               id: "bad-sandbox",
               command: "hostname",
               sandbox: :read_only,
               sandbox_policy: %{command_prefix: [:bad]}
             })
  end

  test "starts a managed local process and forwards output and exit status" do
    spec = ProcessRuntime.spec!(%{id: "echo", command: "printf 'hello\\nworld\\n'"})

    assert {:ok, pid} = ProcessRuntime.start_managed(spec, self())
    assert is_pid(pid)

    assert_receive {:process_output, "echo", "hello"}
    assert_receive {:process_output, "echo", "world"}
    assert_receive {:process_exit, "echo", 0}
  end

  test "supports local pty requests through execution plane" do
    spec = ProcessRuntime.spec!(%{id: "pty", command: "printf 'hello\\n'", pty?: true})

    assert {:ok, pid} = ProcessRuntime.start_managed(spec, self())
    assert is_pid(pid)
    assert_receive {:process_output, "pty", "hello"}
    assert_receive {:process_exit, "pty", 0}
  end

  test "rejects unsupported restricted sandbox requests without an external runner" do
    spec =
      ProcessRuntime.spec!(%{
        id: "readonly",
        command: "printf 'hello\\n'",
        sandbox: :read_only
      })

    assert {:error, {:unsupported_sandbox, :read_only}} =
             ProcessRuntime.start_managed(spec, self())
  end

  test "supports restricted sandbox requests when an explicit external runner is provided" do
    shell = System.find_executable("sh") || "/bin/sh"

    spec =
      ProcessRuntime.spec!(%{
        id: "sandboxed",
        command: "printf 'sandboxed\\n'",
        sandbox: :read_only,
        sandbox_policy: %{command_prefix: [shell, "-lc", "exec \"$@\"", "sandbox"]}
      })

    assert {:ok, pid} = ProcessRuntime.start_managed(spec, self())
    assert is_pid(pid)

    assert_receive {:process_output, "sandboxed", "sandboxed"}
    assert_receive {:process_exit, "sandboxed", 0}
  end

  test "builds a readable ssh exec preview command" do
    spec =
      ProcessRuntime.spec!(%{
        id: "remote",
        command: "hostname",
        execution_surface: %{
          surface_kind: :ssh_exec,
          target_id: "demo.internal",
          transport_options: [port: 2222, user: "deploy", ssh_args: ["-o", "BatchMode=yes"]]
        }
      })

    preview = ProcessRuntime.preview_command(spec)

    assert preview =~ "ssh"
    assert preview =~ "demo.internal"
    assert preview =~ "hostname"
    assert preview =~ "BatchMode=yes"
  end
end
