defmodule Switchyard.ProcessRuntime do
  @moduledoc """
  Switchyard broker layer over Execution Plane managed processes.

  Switchyard no longer owns the subprocess implementation. It normalizes
  product-facing process requests, projects them onto Execution Plane transport
  surfaces, and relays lifecycle output back to the daemon.
  """

  alias __MODULE__.Transport
  alias ExecutionPlane.Process.Transport.Surface, as: EPSurface

  @modes [:inherit, :danger_full_access, :read_only, :workspace_write, :external]
  @forbidden_transport_option_keys [:command, :args, :cwd, :env, :clear_env?]
  @surface_kind_strings %{
    "local_subprocess" => :local_subprocess,
    "ssh_exec" => :ssh_exec
  }
  @transport_option_key_strings %{
    "args" => :args,
    "clear_env?" => :clear_env?,
    "command" => :command,
    "cwd" => :cwd,
    "env" => :env
  }
  @sandbox_mode_strings %{
    "danger_full_access" => :danger_full_access,
    "external" => :external,
    "inherit" => :inherit,
    "read_only" => :read_only,
    "workspace_write" => :workspace_write
  }
  @sandbox_policy_keys [
    :type,
    :writable_roots,
    :network_access,
    :exclude_tmpdir_env_var,
    :exclude_slash_tmp,
    :command_prefix
  ]
  @sandbox_policy_key_strings %{
    "command_prefix" => :command_prefix,
    "exclude_slash_tmp" => :exclude_slash_tmp,
    "exclude_tmpdir_env_var" => :exclude_tmpdir_env_var,
    "network_access" => :network_access,
    "type" => :type,
    "writable_roots" => :writable_roots
  }

  @type spec_error ::
          {:invalid_command, term()}
          | {:invalid_args, term()}
          | {:invalid_env, term()}
          | {:invalid_cwd, term()}
          | {:invalid_user, term()}
          | {:invalid_shell, term()}
          | {:invalid_clear_env, term()}
          | {:invalid_pty, term()}
          | term()

  @type sandbox_mode :: :inherit | :danger_full_access | :read_only | :workspace_write | :external

  @type sandbox_policy :: %{
          optional(:writable_roots) => [String.t()],
          optional(:network_access) => boolean() | :enabled | :restricted,
          optional(:exclude_tmpdir_env_var) => boolean(),
          optional(:exclude_slash_tmp) => boolean(),
          optional(:command_prefix) => [String.t()]
        }

  @type sandbox :: %{
          mode: sandbox_mode(),
          policy: sandbox_policy()
        }

  @type t :: %{
          id: String.t(),
          command: String.t(),
          args: [String.t()],
          shell?: boolean(),
          cwd: String.t() | nil,
          env: %{optional(String.t()) => String.t()},
          clear_env?: boolean(),
          user: String.t() | nil,
          pty?: boolean(),
          execution_surface: EPSurface.t(),
          sandbox: sandbox()
        }

  @spec spec(map() | keyword()) :: {:ok, t()} | {:error, spec_error()}
  def spec(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = Map.new(attrs)

    with {:ok, command} <- normalize_command(fetch(attrs, :command)),
         {:ok, args} <- normalize_args(fetch(attrs, :args, [])),
         {:ok, shell?} <- normalize_boolean(fetch(attrs, :shell?, true), :shell),
         {:ok, env} <- normalize_env(fetch(attrs, :env, %{})),
         {:ok, clear_env?} <- normalize_boolean(fetch(attrs, :clear_env?, false), :clear_env),
         {:ok, pty?} <- normalize_boolean(fetch(attrs, :pty?, false), :pty),
         :ok <- validate_optional_binary(fetch(attrs, :cwd), :cwd),
         :ok <- validate_optional_binary(fetch(attrs, :user), :user),
         {:ok, execution_surface} <- normalize_execution_surface(fetch(attrs, :execution_surface)),
         {:ok, sandbox} <-
           normalize_sandbox(fetch(attrs, :sandbox), fetch(attrs, :sandbox_policy)) do
      {:ok,
       %{
         id: fetch(attrs, :id, "proc-#{System.unique_integer([:positive])}") |> to_string(),
         command: command,
         args: args,
         shell?: shell?,
         cwd: fetch(attrs, :cwd),
         env: env,
         clear_env?: clear_env?,
         user: fetch(attrs, :user),
         pty?: pty?,
         execution_surface: execution_surface,
         sandbox: sandbox
       }}
    end
  end

  @spec spec!(map() | keyword()) :: t()
  def spec!(attrs) do
    case spec(attrs) do
      {:ok, spec} -> spec
      {:error, reason} -> raise ArgumentError, "invalid process spec: #{inspect(reason)}"
    end
  end

  @spec start_managed(t() | map() | keyword(), pid()) :: GenServer.on_start()
  def start_managed(spec_or_attrs, sink_pid) when is_pid(sink_pid) do
    with {:ok, spec} <- ensure_spec(spec_or_attrs) do
      Transport.start_managed(spec, sink_pid)
    end
  end

  @spec preview_command(t() | map() | keyword()) :: String.t()
  def preview_command(spec_or_attrs) do
    case ensure_spec(spec_or_attrs) do
      {:ok, spec} -> Transport.preview_command(spec)
      {:error, reason} -> "invalid command: #{inspect(reason)}"
    end
  end

  @spec requires_external_runner?(sandbox()) :: boolean()
  def requires_external_runner?(%{mode: mode})
      when mode in [:read_only, :workspace_write, :external],
      do: true

  def requires_external_runner?(%{}), do: false

  @spec external_command_prefix(sandbox()) :: [String.t()]
  def external_command_prefix(%{policy: policy}) when is_map(policy) do
    policy
    |> Map.get(:command_prefix, [])
    |> List.wrap()
  end

  defp ensure_spec(
         %{execution_surface: %EPSurface{}, sandbox: %{mode: mode, policy: policy}} = spec
       )
       when is_atom(mode) and is_map(policy),
       do: {:ok, spec}

  defp ensure_spec(attrs) when is_map(attrs) or is_list(attrs), do: spec(attrs)

  defp fetch(attrs, key, default \\ nil) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))
  end

  defp normalize_command(command) when is_binary(command) and command != "", do: {:ok, command}
  defp normalize_command(command), do: {:error, {:invalid_command, command}}

  defp normalize_args(args) when is_list(args) do
    if Enum.all?(args, &is_binary/1) do
      {:ok, args}
    else
      {:error, {:invalid_args, args}}
    end
  end

  defp normalize_args(args), do: {:error, {:invalid_args, args}}

  defp normalize_env(env) when is_map(env) do
    {:ok, Enum.into(env, %{}, fn {key, value} -> {to_string(key), to_string(value)} end)}
  rescue
    Protocol.UndefinedError ->
      {:error, {:invalid_env, env}}
  end

  defp normalize_env(env), do: {:error, {:invalid_env, env}}

  defp normalize_boolean(value, _field) when is_boolean(value), do: {:ok, value}
  defp normalize_boolean(value, field), do: {:error, {invalid_boolean_field(field), value}}

  defp validate_optional_binary(nil, _field), do: :ok
  defp validate_optional_binary(value, _field) when is_binary(value), do: :ok
  defp validate_optional_binary(value, field), do: {:error, {invalid_binary_field(field), value}}

  defp invalid_boolean_field(:clear_env), do: :invalid_clear_env
  defp invalid_boolean_field(:pty), do: :invalid_pty
  defp invalid_boolean_field(:shell), do: :invalid_shell

  defp invalid_binary_field(:cwd), do: :invalid_cwd
  defp invalid_binary_field(:user), do: :invalid_user

  defp normalize_execution_surface(nil), do: EPSurface.new([])
  defp normalize_execution_surface(%EPSurface{} = surface), do: {:ok, surface}

  defp normalize_execution_surface(attrs) when is_list(attrs) do
    if Keyword.keyword?(attrs) do
      build_execution_surface(Map.new(attrs))
    else
      {:error, {:invalid_execution_surface, attrs}}
    end
  end

  defp normalize_execution_surface(%{} = attrs), do: build_execution_surface(attrs)
  defp normalize_execution_surface(other), do: {:error, {:invalid_execution_surface, other}}

  defp build_execution_surface(attrs) do
    transport_options = fetch(attrs, :transport_options)

    with :ok <- reject_forbidden_transport_options(transport_options),
         {:ok, surface_kind} <- normalize_surface_kind(fetch(attrs, :surface_kind)),
         {:ok, transport_options} <- EPSurface.normalize_transport_options(transport_options) do
      [
        surface_kind: surface_kind,
        transport_options: normalize_transport_options_for_surface(transport_options),
        target_id: fetch(attrs, :target_id),
        lease_ref: fetch(attrs, :lease_ref),
        surface_ref: fetch(attrs, :surface_ref),
        boundary_class: fetch(attrs, :boundary_class),
        observability: fetch(attrs, :observability, %{})
      ]
      |> Enum.reject(fn
        {:observability, _value} -> false
        {_key, value} -> is_nil(value)
      end)
      |> EPSurface.new()
    end
  end

  defp normalize_surface_kind(nil), do: {:ok, EPSurface.default_surface_kind()}

  defp normalize_surface_kind(surface_kind) when is_atom(surface_kind),
    do: EPSurface.normalize_surface_kind(surface_kind)

  defp normalize_surface_kind(surface_kind) when is_binary(surface_kind) do
    case Map.fetch(@surface_kind_strings, surface_kind) do
      {:ok, atom} ->
        EPSurface.normalize_surface_kind(atom)

      :error ->
        {:error, {:invalid_surface_kind, surface_kind}}
    end
  end

  defp normalize_surface_kind(surface_kind), do: {:error, {:invalid_surface_kind, surface_kind}}

  defp reject_forbidden_transport_options(nil), do: :ok

  defp reject_forbidden_transport_options(options) when is_list(options) do
    if Keyword.keyword?(options) do
      find_forbidden_transport_option(options)
    else
      :ok
    end
  end

  defp reject_forbidden_transport_options(options) when is_map(options),
    do: find_forbidden_transport_option(options)

  defp reject_forbidden_transport_options(_other), do: :ok

  defp find_forbidden_transport_option(options) do
    case Enum.find(options, fn {key, _value} -> forbidden_transport_option_key?(key) end) do
      nil ->
        :ok

      {key, _value} ->
        {:error, {:forbidden_transport_option, normalize_transport_option_key(key)}}
    end
  end

  defp forbidden_transport_option_key?(key) when is_atom(key),
    do: key in @forbidden_transport_option_keys

  defp forbidden_transport_option_key?(key) when is_binary(key),
    do: key in Enum.map(@forbidden_transport_option_keys, &Atom.to_string/1)

  defp forbidden_transport_option_key?(_key), do: false

  defp normalize_transport_option_key(key) when is_atom(key), do: key

  defp normalize_transport_option_key(key) when is_binary(key) do
    Map.get(@transport_option_key_strings, key, key)
  end

  defp normalize_transport_option_key(key), do: key

  defp normalize_transport_options_for_surface(options) do
    ssh_user = Keyword.get(options, :ssh_user, Keyword.get(options, :user))

    options =
      options
      |> Keyword.delete(:user)

    if is_nil(ssh_user) do
      options
    else
      Keyword.put(options, :ssh_user, ssh_user)
    end
  end

  defp normalize_sandbox(mode, policy) do
    with {:ok, sandbox_mode} <- normalize_sandbox_mode(mode, policy),
         {:ok, sandbox_policy} <- normalize_sandbox_policy(policy) do
      {:ok, %{mode: sandbox_mode, policy: sandbox_policy}}
    end
  end

  defp normalize_sandbox_mode(nil, %{} = policy) do
    case fetch(policy, :type) do
      nil -> {:ok, :inherit}
      type -> normalize_sandbox_mode(type, nil)
    end
  end

  defp normalize_sandbox_mode(nil, _policy), do: {:ok, :inherit}
  defp normalize_sandbox_mode(mode, _policy) when mode in @modes, do: {:ok, mode}

  defp normalize_sandbox_mode(mode, _policy) when is_binary(mode) do
    case Map.fetch(@sandbox_mode_strings, mode) do
      {:ok, atom} -> {:ok, atom}
      :error -> {:error, {:invalid_sandbox_mode, mode}}
    end
  end

  defp normalize_sandbox_mode(mode, _policy), do: {:error, {:invalid_sandbox_mode, mode}}

  defp normalize_sandbox_policy(nil), do: {:ok, %{}}

  defp normalize_sandbox_policy(policy) when is_map(policy) do
    with {:ok, policy} <- normalize_sandbox_policy_keys(policy),
         {:ok, policy} <- validate_sandbox_command_prefix(policy) do
      {:ok, Map.delete(policy, :type)}
    end
  end

  defp normalize_sandbox_policy(policy), do: {:error, {:invalid_sandbox_policy, policy}}

  defp validate_sandbox_command_prefix(%{command_prefix: prefix} = policy) when is_list(prefix) do
    if Enum.all?(prefix, &is_binary/1) do
      {:ok, policy}
    else
      {:error, {:invalid_command_prefix, prefix}}
    end
  end

  defp validate_sandbox_command_prefix(%{command_prefix: prefix}) do
    {:error, {:invalid_command_prefix, prefix}}
  end

  defp validate_sandbox_command_prefix(policy), do: {:ok, policy}

  defp normalize_sandbox_policy_keys(policy) do
    Enum.reduce_while(policy, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case normalize_sandbox_key(key) do
        {:ok, normalized_key} ->
          {:cont, {:ok, Map.put(acc, normalized_key, value)}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp normalize_sandbox_key(key) when is_atom(key) and key in @sandbox_policy_keys,
    do: {:ok, key}

  defp normalize_sandbox_key(key) when is_atom(key),
    do: {:error, {:invalid_sandbox_policy_key, Atom.to_string(key)}}

  defp normalize_sandbox_key(key) when is_binary(key) do
    case Map.fetch(@sandbox_policy_key_strings, key) do
      {:ok, atom} -> {:ok, atom}
      :error -> {:error, {:invalid_sandbox_policy_key, key}}
    end
  end

  defp normalize_sandbox_key(key), do: {:error, {:invalid_sandbox_policy_key, key}}
end
