defmodule Switchyard.Contracts.GovernedRouteAuthority do
  @moduledoc """
  Bounded authority packet for governed Switchyard routing and dispatch.

  Standalone Switchyard calls may still pass explicit process env, operator
  transport, daemon routing, and site config. When a governed authority packet
  is present, those authority-bearing fields must be materialized from this
  packet instead of from env, Application config, singleton clients, or direct
  request fields.
  """

  @enforce_keys [:authority_ref]
  defstruct authority_ref: nil,
            route_id: nil,
            provider_id: nil,
            target_id: nil,
            credential_ref: nil,
            env: %{},
            clear_env?: true,
            execution_surface: nil,
            operator_transport: [],
            site_modules: []

  @type t :: %__MODULE__{
          authority_ref: String.t(),
          route_id: String.t() | nil,
          provider_id: String.t() | nil,
          target_id: String.t() | nil,
          credential_ref: map() | nil,
          env: %{optional(String.t()) => String.t()},
          clear_env?: boolean(),
          execution_surface: map() | keyword() | nil,
          operator_transport: keyword(),
          site_modules: [module()]
        }

  @operator_transport_key_strings %{
    "auth_methods" => :auth_methods,
    "auto_host_key" => :auto_host_key,
    "boundary_class" => :boundary_class,
    "daemon_starter" => :daemon_starter,
    "daemon_stopper" => :daemon_stopper,
    "observability" => :observability,
    "port" => :port,
    "surface_ref" => :surface_ref,
    "transport" => :transport,
    "user_passwords" => :user_passwords
  }
  @operator_transport_keys Map.values(@operator_transport_key_strings)
  @transport_strings %{
    "distributed" => :distributed,
    "local" => :local,
    "ssh" => :ssh
  }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = Map.new(attrs)

    with {:ok, authority_ref} <- required_string(attrs, :authority_ref),
         {:ok, env} <- normalize_env(fetch(attrs, :env, %{})),
         {:ok, clear_env?} <- normalize_boolean(fetch(attrs, :clear_env?, true), :clear_env?),
         {:ok, operator_transport} <-
           normalize_operator_transport(fetch(attrs, :operator_transport)),
         {:ok, site_modules} <- normalize_site_modules(fetch(attrs, :site_modules, [])) do
      {:ok,
       %__MODULE__{
         authority_ref: authority_ref,
         route_id: optional_string(fetch(attrs, :route_id)),
         provider_id: optional_string(fetch(attrs, :provider_id)),
         target_id: optional_string(fetch(attrs, :target_id)),
         credential_ref: normalize_credential_ref(fetch(attrs, :credential_ref)),
         env: env,
         clear_env?: clear_env?,
         execution_surface: fetch(attrs, :execution_surface),
         operator_transport: operator_transport,
         site_modules: site_modules
       }}
    end
  end

  def new(attrs), do: {:error, {:invalid_governed_authority, attrs}}

  @spec new!(map() | keyword()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, authority} ->
        authority

      {:error, reason} ->
        raise ArgumentError, "invalid governed route authority: #{inspect(reason)}"
    end
  end

  @spec process_attrs(t()) :: map()
  def process_attrs(%__MODULE__{} = authority) do
    %{
      authority_ref: authority.authority_ref,
      clear_env?: authority.clear_env?,
      env: authority.env
    }
    |> maybe_put(:execution_surface, authority.execution_surface)
  end

  @spec operator_terminal_opts(t()) :: keyword()
  def operator_terminal_opts(%__MODULE__{} = authority), do: authority.operator_transport

  @spec daemon_opts(t()) :: keyword()
  def daemon_opts(%__MODULE__{site_modules: []}), do: []
  def daemon_opts(%__MODULE__{site_modules: site_modules}), do: [site_modules: site_modules]

  @spec redaction_values(t()) :: [String.t()]
  def redaction_values(%__MODULE__{} = authority) do
    authority.env
    |> Map.values()
    |> Enum.map(&to_string/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp required_string(attrs, key) do
    case optional_string(fetch(attrs, key)) do
      nil -> {:error, {:missing_required_authority_field, key}}
      value -> {:ok, value}
    end
  end

  defp optional_string(nil), do: nil
  defp optional_string(value) when is_binary(value) and value != "", do: value
  defp optional_string(value) when is_atom(value), do: Atom.to_string(value)
  defp optional_string(value), do: to_string(value)

  defp normalize_env(nil), do: {:ok, %{}}

  defp normalize_env(env) when is_map(env) do
    {:ok, Map.new(env, fn {key, value} -> {to_string(key), to_string(value)} end)}
  rescue
    Protocol.UndefinedError -> {:error, {:invalid_authority_env, env}}
  end

  defp normalize_env(env), do: {:error, {:invalid_authority_env, env}}

  defp normalize_boolean(value, _field) when is_boolean(value), do: {:ok, value}
  defp normalize_boolean(value, field), do: {:error, {:invalid_authority_boolean, field, value}}

  defp normalize_credential_ref(nil), do: nil
  defp normalize_credential_ref(%{} = credential_ref), do: credential_ref
  defp normalize_credential_ref(credential_ref), do: %{ref: credential_ref}

  defp normalize_site_modules(modules) when is_list(modules) do
    if Enum.all?(modules, &is_atom/1) do
      {:ok, modules}
    else
      {:error, {:invalid_authority_site_modules, modules}}
    end
  end

  defp normalize_site_modules(modules), do: {:error, {:invalid_authority_site_modules, modules}}

  defp normalize_operator_transport(nil), do: {:ok, []}

  defp normalize_operator_transport(transport) when is_map(transport) or is_list(transport) do
    Enum.reduce_while(transport, {:ok, []}, fn {key, value}, {:ok, acc} ->
      with {:ok, normalized_key} <- normalize_operator_transport_key(key),
           {:ok, normalized_value} <- normalize_operator_transport_value(normalized_key, value) do
        {:cont, {:ok, Keyword.put(acc, normalized_key, normalized_value)}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp normalize_operator_transport(transport),
    do: {:error, {:invalid_operator_transport, transport}}

  defp normalize_operator_transport_key(key) when key in @operator_transport_keys, do: {:ok, key}

  defp normalize_operator_transport_key(key) when is_binary(key) do
    case Map.fetch(@operator_transport_key_strings, key) do
      {:ok, normalized_key} -> {:ok, normalized_key}
      :error -> {:error, {:invalid_operator_transport_key, key}}
    end
  end

  defp normalize_operator_transport_key(key),
    do: {:error, {:invalid_operator_transport_key, key}}

  defp normalize_operator_transport_value(:transport, value) when is_atom(value),
    do: {:ok, value}

  defp normalize_operator_transport_value(:transport, value) when is_binary(value) do
    case Map.fetch(@transport_strings, value) do
      {:ok, transport} -> {:ok, transport}
      :error -> {:error, {:invalid_operator_transport_value, :transport, value}}
    end
  end

  defp normalize_operator_transport_value(:auth_methods, value) when is_binary(value),
    do: {:ok, String.to_charlist(value)}

  defp normalize_operator_transport_value(:auth_methods, value) when is_list(value),
    do: {:ok, value}

  defp normalize_operator_transport_value(:user_passwords, value) when is_list(value) do
    {:ok,
     Enum.map(value, fn
       {user, password} -> {to_charlist_value(user), to_charlist_value(password)}
       other -> other
     end)}
  end

  defp normalize_operator_transport_value(_key, value), do: {:ok, value}

  defp to_charlist_value(value) when is_binary(value), do: String.to_charlist(value)
  defp to_charlist_value(value), do: value

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp fetch(attrs, key, default \\ nil) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))
  end
end
