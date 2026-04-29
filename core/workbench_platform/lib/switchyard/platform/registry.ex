defmodule Switchyard.Platform.Registry do
  @moduledoc """
  Registry helpers for site provider modules.
  """

  alias Switchyard.Contracts.{Action, AppDescriptor, Resource, SiteDescriptor}
  alias Switchyard.Contracts.SiteProvider

  @spec sites([module()]) :: [SiteDescriptor.t()]
  def sites(site_modules) when is_list(site_modules) do
    Enum.map(site_modules, &site_definition!/1)
  end

  @spec site(String.t(), [module()]) :: SiteDescriptor.t() | nil
  def site(site_id, site_modules) when is_binary(site_id) do
    Enum.find_value(site_modules, fn module ->
      case site_definition!(module) do
        %SiteDescriptor{id: ^site_id} = descriptor -> descriptor
        _descriptor -> nil
      end
    end)
  end

  @spec apps(String.t(), [module()]) :: [AppDescriptor.t()]
  def apps(site_id, site_modules) when is_binary(site_id) do
    case provider(site_id, site_modules) do
      nil -> []
      module -> module.apps()
    end
  end

  @spec actions(String.t(), [module()]) :: [Action.t()]
  def actions(site_id, site_modules) when is_binary(site_id) do
    case provider(site_id, site_modules) do
      nil -> []
      module -> action_definitions!(module)
    end
  end

  @spec actions([module()]) :: [Action.t()]
  def actions(site_modules) when is_list(site_modules) do
    site_modules
    |> Enum.flat_map(&action_definitions!/1)
    |> reject_duplicate_action_ids!()
  end

  @spec fetch_action(String.t(), [module()]) :: {:ok, Action.t()} | :error
  def fetch_action(action_id, site_modules) when is_binary(action_id) and is_list(site_modules) do
    site_modules
    |> actions()
    |> Enum.find(fn action -> action.id == action_id end)
    |> case do
      nil -> :error
      action -> {:ok, action}
    end
  end

  @spec actions_for_resource(Resource.t(), [module()], map()) :: [Action.t()]
  def actions_for_resource(%Resource{} = resource, site_modules, _snapshot \\ %{})
      when is_list(site_modules) do
    site_modules
    |> actions()
    |> Enum.filter(&action_matches_resource?(&1, resource))
  end

  @spec provider(String.t(), [module()]) :: module() | nil
  def provider(site_id, site_modules) when is_binary(site_id) do
    Enum.find(site_modules, fn module ->
      site_definition!(module).id == site_id
    end)
  end

  defp site_definition!(module) do
    case Code.ensure_loaded(module) do
      {:module, ^module} ->
        if function_exported?(module, :site_definition, 0) do
          module.site_definition()
        else
          raise ArgumentError, "#{inspect(module)} does not implement #{inspect(SiteProvider)}"
        end

      {:error, _reason} ->
        raise ArgumentError, "#{inspect(module)} could not be loaded"
    end
  end

  defp action_definitions!(module) do
    ensure_provider_callback!(module, :actions, 0)

    case module.actions() do
      actions when is_list(actions) ->
        Enum.map(actions, &validate_action_definition!(&1, module))

      other ->
        raise ArgumentError,
              "#{inspect(module)} action definitions must be a list, got: #{inspect(other)}"
    end
  end

  defp validate_action_definition!(%Action{} = action, module) do
    cond do
      not valid_action_id?(action.id) ->
        invalid_action!(module, action, "id must be a non-empty string")

      not valid_title?(action.title) ->
        invalid_action!(module, action, "title must be a non-empty string")

      not valid_scope?(action.scope) ->
        invalid_action!(module, action, "scope is not supported")

      not is_atom(action.provider) ->
        invalid_action!(module, action, "provider must be a module atom")

      not is_map(action.input_schema) ->
        invalid_action!(module, action, "input_schema must be a map")

      action.confirmation not in [:never, :if_destructive, :always] ->
        invalid_action!(module, action, "confirmation is not supported")

      true ->
        action
    end
  end

  defp validate_action_definition!(action, module) do
    raise ArgumentError,
          "#{inspect(module)} action definitions must be %Switchyard.Contracts.Action{}, got: #{inspect(action)}"
  end

  defp reject_duplicate_action_ids!(actions) do
    {_seen, deduped} =
      Enum.reduce(actions, {MapSet.new(), []}, fn action, {seen, acc} ->
        if MapSet.member?(seen, action.id) do
          raise ArgumentError, "duplicate action id #{inspect(action.id)}"
        end

        {MapSet.put(seen, action.id), [action | acc]}
      end)

    Enum.reverse(deduped)
  end

  defp action_matches_resource?(%Action{scope: {:resource, kind}}, %Resource{kind: kind}),
    do: true

  defp action_matches_resource?(
         %Action{scope: {:resource_instance, site_id, kind, resource_id}},
         %Resource{site_id: site_id, kind: kind, id: resource_id}
       ),
       do: true

  defp action_matches_resource?(_action, _resource), do: false

  defp valid_action_id?(id), do: is_binary(id) and String.trim(id) != ""

  defp valid_title?(title), do: is_binary(title) and String.trim(title) != ""

  defp valid_scope?({:global, namespace}), do: is_atom(namespace) or is_binary(namespace)
  defp valid_scope?({:site, site_id}), do: is_binary(site_id) and site_id != ""
  defp valid_scope?({:app, app_id}), do: is_binary(app_id) and app_id != ""
  defp valid_scope?({:resource, kind}), do: is_atom(kind)

  defp valid_scope?({:resource_instance, site_id, kind, resource_id}) do
    is_binary(site_id) and site_id != "" and is_atom(kind) and is_binary(resource_id) and
      resource_id != ""
  end

  defp valid_scope?(_scope), do: false

  defp invalid_action!(module, action, reason) do
    raise ArgumentError,
          "#{inspect(module)} action definitions include invalid action #{inspect(action.id)}: #{reason}"
  end

  defp ensure_provider_callback!(module, name, arity) do
    case Code.ensure_loaded(module) do
      {:module, ^module} ->
        unless function_exported?(module, name, arity) do
          raise ArgumentError, "#{inspect(module)} does not implement #{inspect(SiteProvider)}"
        end

      {:error, _reason} ->
        raise ArgumentError, "#{inspect(module)} could not be loaded"
    end
  end
end
