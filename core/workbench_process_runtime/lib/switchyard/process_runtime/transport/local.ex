defmodule Switchyard.ProcessRuntime.Transport.Local do
  @moduledoc false

  alias ExecutionPlane.Command
  alias Switchyard.ProcessRuntime
  alias Switchyard.ProcessRuntime.Transport.Support

  @shell_fallback "/bin/sh"

  @spec validate(ProcessRuntime.t()) :: :ok | {:error, term()}
  def validate(%{sandbox: sandbox}) when is_map(sandbox) do
    case ProcessRuntime.requires_external_runner?(sandbox) do
      true ->
        if ProcessRuntime.external_command_prefix(sandbox) == [] do
          {:error, {:unsupported_sandbox, sandbox.mode}}
        else
          :ok
        end

      false ->
        :ok
    end
  end

  @spec command_plan(ProcessRuntime.t()) :: {:ok, map()} | {:error, term()}
  def command_plan(spec) when is_map(spec) do
    with :ok <- validate(spec) do
      command = spec |> base_command() |> maybe_prefix_sandbox(spec.sandbox)

      {:ok,
       %{
         command: command,
         surface_kind: :local_subprocess,
         target_id: spec.execution_surface.target_id,
         surface_ref: spec.execution_surface.surface_ref,
         transport_options: spec.execution_surface.transport_options,
         boundary_class: spec.execution_surface.boundary_class,
         observability: spec.execution_surface.observability,
         pty?: spec.pty?,
         description: describe(spec)
       }}
    end
  end

  @spec preview_command(ProcessRuntime.t()) :: String.t()
  def preview_command(spec) when is_map(spec), do: describe(spec)

  defp base_command(spec) when is_map(spec) do
    if spec.shell? do
      Command.new(resolve_shell_path(), ["-lc", spec.command],
        cwd: spec.cwd,
        env: spec.env,
        clear_env?: spec.clear_env?,
        user: spec.user
      )
    else
      Command.new(spec.command, spec.args,
        cwd: spec.cwd,
        env: spec.env,
        clear_env?: spec.clear_env?,
        user: spec.user
      )
    end
  end

  defp maybe_prefix_sandbox(%Command{} = command, sandbox) do
    case ProcessRuntime.external_command_prefix(sandbox) do
      [] ->
        command

      [program | prefix_args] ->
        Command.new(program, prefix_args ++ Command.argv(command),
          cwd: command.cwd,
          env: command.env,
          clear_env?: command.clear_env?,
          user: command.user
        )
    end
  end

  defp describe(spec) do
    "#{cwd_prefix(spec.cwd)}#{sandbox_prefix(spec.sandbox)}#{env_prefix(spec)}#{command_string(spec)}"
  end

  defp resolve_shell_path, do: Support.resolve_executable("sh", @shell_fallback)

  defp cwd_prefix(nil), do: ""
  defp cwd_prefix(cwd), do: "cd #{Support.shell_escape(cwd)} && "

  defp env_prefix(%{clear_env?: true, env: env}) when map_size(env) == 0, do: "env -i "

  defp env_prefix(%{clear_env?: true, env: env}) do
    "env -i #{Enum.join(Support.env_assignments(env), " ")} "
  end

  defp env_prefix(%{env: env}) when map_size(env) == 0, do: ""
  defp env_prefix(%{env: env}), do: Enum.join(Support.env_assignments(env), " ") <> " "

  defp command_string(%{shell?: true, command: command}), do: command
  defp command_string(%{command: command, args: args}), do: Support.shell_join([command | args])

  defp sandbox_prefix(sandbox) do
    case ProcessRuntime.external_command_prefix(sandbox) do
      [] -> ""
      prefix -> Support.shell_join(prefix) <> " "
    end
  end
end
