defmodule Switchyard.TUI.App do
  @moduledoc false

  use ExRatatui.App, runtime: :reducer

  alias ExRatatui.{Event, Frame}
  alias Switchyard.Platform
  alias Switchyard.Site.Local
  alias Switchyard.TUI.{Controller, Model, Renderer}

  @impl true
  def init(opts) do
    catalog = Platform.catalog(site_modules(opts))
    mount_modules = build_mount_modules(opts)
    mount_states = build_mount_states(mount_modules, opts)

    model =
      Model.new(
        sites: catalog.sites,
        apps: catalog.apps,
        snapshot: Keyword.get(opts, :snapshot, %{processes: [], jobs: []}),
        context: Map.new(opts),
        mount_modules: mount_modules,
        mount_states: mount_states
      )

    case Keyword.get(opts, :open_app) do
      app_id when is_binary(app_id) and app_id != "" ->
        {next_state, commands} = Controller.open_app(model, app_id)
        {:ok, next_state, commands: commands}

      _other ->
        {:ok, model}
    end
  end

  @impl true
  def render(%Model{} = state, %Frame{} = frame), do: Renderer.widgets(state, frame)

  @impl true
  def update({:event, %Event.Key{kind: "press"} = event}, state) do
    case Controller.event_to_msg(event, state) do
      :ignore -> {:noreply, state}
      {:msg, msg} -> runtime_reply(Controller.update(msg, state))
    end
  end

  def update({:event, %Event.Resize{width: width, height: height}}, state),
    do: runtime_reply(Controller.update({:resize, width, height}, state))

  def update({:event, _event}, state), do: {:noreply, state}
  def update({:info, msg}, state), do: runtime_reply(Controller.update(msg, state))

  defp runtime_reply({:stop, state}), do: {:stop, state}
  defp runtime_reply({state, commands}), do: {:noreply, state, commands: commands}

  defp site_modules(opts), do: Keyword.get(opts, :site_modules, [Local])

  defp build_mount_modules(opts) do
    opts
    |> Keyword.get(:mount_modules, [])
    |> Enum.reduce(%{}, fn module, acc -> Map.put(acc, module.id(), module) end)
  end

  defp build_mount_states(mount_modules, opts) do
    Map.new(mount_modules, fn {id, module} -> {id, module.init(opts)} end)
  end
end
