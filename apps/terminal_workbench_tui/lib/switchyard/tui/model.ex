defmodule Switchyard.TUI.Model do
  @moduledoc """
  Host state for the generic Switchyard TUI application.
  """

  alias Switchyard.Contracts.{AppDescriptor, Resource, ResourceDetail}
  alias Switchyard.Shell

  @enforce_keys []
  defstruct shell: Shell.new(),
            sites: [],
            apps: [],
            home_cursor: 0,
            site_app_cursor: 0,
            resource_cursor: 0,
            screen_width: 0,
            screen_height: 0,
            status_line: "Ready",
            status_severity: :info,
            snapshot: %{processes: [], jobs: []},
            context: %{},
            mount_modules: %{},
            mount_states: %{}

  @type t :: %__MODULE__{
          shell: Shell.State.t(),
          sites: [map()],
          apps: [AppDescriptor.t()],
          home_cursor: non_neg_integer(),
          site_app_cursor: non_neg_integer(),
          resource_cursor: non_neg_integer(),
          screen_width: non_neg_integer(),
          screen_height: non_neg_integer(),
          status_line: String.t(),
          status_severity: :info | :warn | :error,
          snapshot: map(),
          context: map(),
          mount_modules: %{optional(String.t()) => module()},
          mount_states: %{optional(String.t()) => term()}
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end

  @spec move_home_cursor(t(), integer()) :: t()
  def move_home_cursor(%__MODULE__{} = state, delta) when is_integer(delta) do
    %{state | home_cursor: clamp_index(state.home_cursor + delta, state.sites)}
  end

  @spec selected_home_site(t()) :: map() | nil
  def selected_home_site(%__MODULE__{} = state), do: Enum.at(state.sites, state.home_cursor)

  @spec move_site_app_cursor(t(), integer()) :: t()
  def move_site_app_cursor(%__MODULE__{} = state, delta) when is_integer(delta) do
    %{
      state
      | site_app_cursor: clamp_index(state.site_app_cursor + delta, apps_for_selected_site(state))
    }
  end

  @spec selected_site_app(t()) :: AppDescriptor.t() | nil
  def selected_site_app(%__MODULE__{} = state) do
    Enum.at(apps_for_selected_site(state), state.site_app_cursor)
  end

  @spec move_resource_cursor(t(), integer()) :: t()
  def move_resource_cursor(%__MODULE__{} = state, delta) when is_integer(delta) do
    %{
      state
      | resource_cursor:
          clamp_index(state.resource_cursor + delta, resources_for_selected_app(state))
    }
  end

  @spec selected_resource(t()) :: Resource.t() | nil
  def selected_resource(%__MODULE__{} = state) do
    Enum.at(resources_for_selected_app(state), state.resource_cursor)
  end

  @spec apps_for_selected_site(t()) :: [AppDescriptor.t()]
  def apps_for_selected_site(%__MODULE__{} = state) do
    selected_site_id =
      state.shell.selected_site_id ||
        case selected_home_site(state) do
          %{id: site_id} -> site_id
          _other -> nil
        end

    Enum.filter(state.apps, &(&1.site_id == selected_site_id))
  end

  @spec resources_for_selected_app(t()) :: [Resource.t()]
  def resources_for_selected_app(%__MODULE__{} = state) do
    case current_app(state) do
      %AppDescriptor{} = app ->
        state.snapshot
        |> app.provider.resources()
        |> Enum.filter(&resource_matches_app?(&1, app))

      _other ->
        []
    end
  end

  @spec detail_for_selected_resource(t()) :: ResourceDetail.t() | nil
  def detail_for_selected_resource(%__MODULE__{} = state) do
    case {current_app(state), selected_resource(state)} do
      {%AppDescriptor{} = app, %Resource{} = resource} ->
        app.provider.detail(resource, state.snapshot)

      _other ->
        nil
    end
  end

  @spec set_status(t(), String.t(), :info | :warn | :error) :: t()
  def set_status(%__MODULE__{} = state, line, severity)
      when is_binary(line) and severity in [:info, :warn, :error] do
    %{state | status_line: line, status_severity: severity}
  end

  @spec current_mount_module(t()) :: module() | nil
  def current_mount_module(%__MODULE__{} = state) do
    Map.get(state.mount_modules, state.shell.selected_app_id)
  end

  @spec current_mount_state(t()) :: term()
  def current_mount_state(%__MODULE__{} = state) do
    Map.get(state.mount_states, state.shell.selected_app_id)
  end

  @spec put_mount_state(t(), String.t(), term()) :: t()
  def put_mount_state(%__MODULE__{} = state, app_id, mount_state) when is_binary(app_id) do
    %{state | mount_states: Map.put(state.mount_states, app_id, mount_state)}
  end

  @spec select_site(t(), String.t()) :: t()
  def select_site(%__MODULE__{} = state, site_id) when is_binary(site_id) do
    %{
      state
      | shell: Shell.reduce(state.shell, {:select_site, site_id}),
        site_app_cursor: 0,
        resource_cursor: 0
    }
  end

  @spec select_app(t(), String.t()) :: t()
  def select_app(%__MODULE__{} = state, app_id) when is_binary(app_id) do
    %{state | shell: Shell.reduce(state.shell, {:select_app, app_id}), resource_cursor: 0}
  end

  defp current_app(%__MODULE__{} = state) do
    Enum.find(state.apps, &(&1.id == state.shell.selected_app_id))
  end

  defp resource_matches_app?(%Resource{} = resource, %AppDescriptor{} = app) do
    resource.site_id == app.site_id and
      (app.resource_kinds == [] or resource.kind in app.resource_kinds)
  end

  defp clamp_index(_index, []), do: 0
  defp clamp_index(index, items), do: index |> max(0) |> min(length(items) - 1)
end
