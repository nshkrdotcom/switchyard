defmodule Switchyard.ProcessRuntime.Transport.SSHExec do
  @moduledoc false

  alias ExecutionPlane.Command
  alias Switchyard.ProcessRuntime
  alias Switchyard.ProcessRuntime.Transport.Support

  @spec validate(ProcessRuntime.t()) :: :ok | {:error, term()}
  def validate(%{execution_surface: execution_surface, sandbox: sandbox}) do
    [
      validate_host(execution_surface),
      validate_transport_options(execution_surface.transport_options),
      validate_sandbox(sandbox)
    ]
    |> Enum.find(:ok, &(&1 != :ok))
  end

  @spec command_plan(ProcessRuntime.t()) :: {:ok, map()} | {:error, term()}
  def command_plan(spec) when is_map(spec) do
    with :ok <- validate(spec) do
      destination = destination(spec.execution_surface)
      command = spec |> base_command() |> maybe_prefix_sandbox(spec.sandbox)

      {:ok,
       %{
         command: command,
         surface_kind: :ssh_exec,
         target_id: spec.execution_surface.target_id || destination,
         surface_ref: spec.execution_surface.surface_ref,
         boundary_class: spec.execution_surface.boundary_class,
         observability: spec.execution_surface.observability,
         transport_options: execution_plane_transport_options(spec.execution_surface),
         pty?: spec.pty?,
         description: preview_command(spec)
       }}
    end
  end

  @spec preview_command(ProcessRuntime.t()) :: String.t()
  def preview_command(spec) when is_map(spec) do
    transport_options = spec.execution_surface.transport_options
    ssh_path = Support.resolve_executable("ssh", "/usr/bin/ssh")
    ssh_args = build_ssh_args(transport_options, destination(spec.execution_surface))
    remote_command = build_remote_command(spec)
    Support.shell_join([ssh_path | ssh_args ++ [remote_command]])
  end

  defp base_command(spec) when is_map(spec) do
    Command.new(spec.command, spec.args,
      cwd: spec.cwd,
      env: spec.env,
      clear_env?: spec.clear_env?,
      user: spec.user
    )
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

  defp execution_plane_transport_options(execution_surface) do
    opts = execution_surface.transport_options

    []
    |> maybe_put(:destination, destination(execution_surface))
    |> maybe_put(:port, Keyword.get(opts, :port))
    |> maybe_put(:ssh_user, ssh_user(opts))
    |> maybe_put(:identity_file, Keyword.get(opts, :identity_file))
    |> maybe_put(:ssh_args, Keyword.get(opts, :ssh_args))
    |> maybe_put(:ssh_path, Keyword.get(opts, :ssh_path))
  end

  defp build_ssh_args(transport_options, destination) do
    []
    |> maybe_add_pair("-p", Keyword.get(transport_options, :port))
    |> maybe_add_pair("-l", ssh_user(transport_options))
    |> maybe_add_pair("-i", Keyword.get(transport_options, :identity_file))
    |> Kernel.++(Keyword.get(transport_options, :ssh_args, []))
    |> Kernel.++([destination])
  end

  defp build_remote_command(spec) when is_map(spec) do
    command =
      if spec.shell? do
        spec.command
      else
        Support.shell_join([spec.command | spec.args])
      end

    command
    |> maybe_prefix_sandbox_command(spec.sandbox)
    |> maybe_prefix_env(spec.env, spec.clear_env?)
    |> maybe_prefix_cwd(spec.cwd)
  end

  defp maybe_prefix_sandbox_command(command, sandbox) do
    case ProcessRuntime.external_command_prefix(sandbox) do
      [] -> command
      prefix -> Support.shell_join(prefix) <> " " <> command
    end
  end

  defp maybe_prefix_env(command, env, clear_env?) do
    prefix =
      cond do
        clear_env? and map_size(env) == 0 ->
          "env -i"

        clear_env? ->
          "env -i " <> Enum.join(Support.env_assignments(env), " ")

        map_size(env) == 0 ->
          nil

        true ->
          Enum.join(Support.env_assignments(env), " ")
      end

    case prefix do
      nil -> command
      prefix -> prefix <> " " <> command
    end
  end

  defp maybe_prefix_cwd(command, nil), do: command
  defp maybe_prefix_cwd(command, cwd), do: "cd #{Support.shell_escape(cwd)} && #{command}"

  defp validate_host(%{target_id: target_id, transport_options: opts}) do
    host = Keyword.get(opts, :host, target_id)

    if is_binary(host) and host != "" do
      :ok
    else
      {:error, :missing_ssh_host}
    end
  end

  defp validate_sandbox(sandbox) when is_map(sandbox) do
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

  defp validate_transport_options(opts) do
    case Keyword.get(opts, :ssh_args, []) do
      ssh_args when is_list(ssh_args) ->
        if Enum.all?(ssh_args, &is_binary/1) do
          :ok
        else
          {:error, {:invalid_ssh_args, ssh_args}}
        end

      invalid ->
        {:error, {:invalid_ssh_args, invalid}}
    end
  end

  defp destination(execution_surface) do
    Keyword.get(execution_surface.transport_options, :host, execution_surface.target_id)
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, []), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp maybe_add_pair(args, _flag, nil), do: args
  defp maybe_add_pair(args, flag, value), do: args ++ [flag, to_string(value)]

  defp ssh_user(opts), do: Keyword.get(opts, :ssh_user, Keyword.get(opts, :user))
end
