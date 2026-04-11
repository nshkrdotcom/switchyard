defmodule Switchyard.TUI.Renderer do
  @moduledoc false

  alias ExRatatui.{Frame, Layout}
  alias Switchyard.Contracts.ResourceDetail
  alias Switchyard.TUI.{HomeScreen, Model, ScreenUI}

  @spec widgets(Model.t(), Frame.t()) :: list()
  def widgets(%Model{} = state, %Frame{} = frame) do
    case state.shell.route do
      :home -> home_widgets(state, frame)
      :site_apps -> site_apps_widgets(state, frame)
      :app -> app_widgets(state, frame)
      _other -> home_widgets(state, frame)
    end
  end

  defp home_widgets(state, frame) do
    area = ScreenUI.root_area(frame)

    [header_area, body_area, footer_area, status_area] =
      Layout.split(area, :vertical, [{:length, 3}, {:min, 10}, {:length, 2}, {:length, 1}])

    home_model = HomeScreen.view_model(state.snapshot, state.sites)

    site_lines =
      home_model.sites
      |> Enum.with_index()
      |> Enum.map(fn {title, index} ->
        if index == state.home_cursor, do: "> #{title}", else: "  #{title}"
      end)

    [
      {ScreenUI.pane(home_model.title, [home_model.tagline], border_fg: :cyan), header_area},
      {ScreenUI.pane("Sites", site_lines, border_fg: :yellow), body_area},
      {ScreenUI.text_widget("Up/Down select site  ·  Enter open  ·  Ctrl+Q quit",
         style: ScreenUI.meta_style()
       ), footer_area},
      {ScreenUI.text_widget(state.status_line,
         style: ScreenUI.status_style(state.status_severity),
         wrap: false
       ), status_area}
    ]
  end

  defp site_apps_widgets(state, frame) do
    area = ScreenUI.root_area(frame)

    [header_area, body_area, footer_area, status_area] =
      Layout.split(area, :vertical, [{:length, 3}, {:min, 10}, {:length, 2}, {:length, 1}])

    selected_site =
      Model.selected_home_site(state) || %{title: state.shell.selected_site_id || "Site"}

    app_lines =
      state
      |> Model.apps_for_selected_site()
      |> Enum.with_index()
      |> Enum.map(fn {app, index} ->
        prefix = if index == state.site_app_cursor, do: "> ", else: "  "
        "#{prefix}#{app.title}"
      end)

    [
      {ScreenUI.pane(selected_site.title, ["Installed apps"], border_fg: :cyan), header_area},
      {ScreenUI.pane("Apps", app_lines, border_fg: :yellow), body_area},
      {ScreenUI.text_widget("Up/Down select app  ·  Enter open  ·  Esc home  ·  Ctrl+Q quit",
         style: ScreenUI.meta_style()
       ), footer_area},
      {ScreenUI.text_widget(state.status_line,
         style: ScreenUI.status_style(state.status_severity),
         wrap: false
       ), status_area}
    ]
  end

  defp app_widgets(%Model{} = state, %Frame{} = frame) do
    case Model.current_mount_module(state) do
      nil -> generic_app_widgets(state, frame)
      module -> module.render(state, frame, Model.current_mount_state(state))
    end
  end

  defp generic_app_widgets(state, frame) do
    area = ScreenUI.root_area(frame)

    [header_area, body_area, footer_area, status_area] =
      Layout.split(area, :vertical, [{:length, 3}, {:min, 10}, {:length, 2}, {:length, 1}])

    [list_area, detail_area] =
      Layout.split(body_area, :horizontal, [{:percentage, 42}, {:percentage, 58}])

    app = Model.selected_site_app(state)

    resource_lines =
      state
      |> Model.resources_for_selected_app()
      |> Enum.with_index()
      |> Enum.map(fn {resource, index} ->
        prefix = if index == state.resource_cursor, do: "> ", else: "  "
        "#{prefix}#{resource.title}#{resource_subtitle(resource)}"
      end)

    detail_lines = detail_lines(Model.detail_for_selected_resource(state))

    [
      {ScreenUI.pane(app_title(app), [app_subtitle(app)], border_fg: :cyan), header_area},
      {ScreenUI.pane("Resources", resource_lines, border_fg: :yellow), list_area},
      {ScreenUI.pane("Detail", detail_lines, border_fg: :green), detail_area},
      {ScreenUI.text_widget("Up/Down select resource  ·  Esc back  ·  Ctrl+Q quit",
         style: ScreenUI.meta_style()
       ), footer_area},
      {ScreenUI.text_widget(state.status_line,
         style: ScreenUI.status_style(state.status_severity),
         wrap: false
       ), status_area}
    ]
  end

  defp app_title(nil), do: "App"
  defp app_title(app), do: app.title

  defp app_subtitle(nil), do: "No app selected"
  defp app_subtitle(app), do: "Route kind: #{app.route_kind}"

  defp resource_subtitle(%{subtitle: nil}), do: ""
  defp resource_subtitle(%{subtitle: subtitle}), do: "  ·  #{subtitle}"

  defp detail_lines(nil), do: ["No detail available."]

  defp detail_lines(%ResourceDetail{} = detail) do
    sections =
      detail.sections
      |> Enum.flat_map(fn section ->
        [section.title] ++ Enum.map(section.lines, &"  #{&1}")
      end)

    recommendations =
      if detail.recommended_actions == [] do
        []
      else
        ["", "Recommended Actions"] ++ Enum.map(detail.recommended_actions, &"  #{&1}")
      end

    sections ++ recommendations
  end
end
