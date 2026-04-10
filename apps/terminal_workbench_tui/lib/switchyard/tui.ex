defmodule Switchyard.TUI do
  @moduledoc """
  Minimal terminal host entrypoint and render model helpers.
  """

  alias Switchyard.Shell

  defmodule HomeScreen do
    @moduledoc "Home screen view-model and draw-spec helpers."

    @spec view_model(map(), [map()]) :: map()
    def view_model(snapshot, sites) when is_map(snapshot) and is_list(sites) do
      %{
        title: "Switchyard",
        tagline: "Terminal workbench for sites, jobs, logs, and processes",
        sites: Enum.map(sites, & &1.title),
        process_count: length(Map.get(snapshot, :processes, [])),
        job_count: length(Map.get(snapshot, :jobs, []))
      }
    end

    @spec draw_spec(map()) :: map()
    def draw_spec(model) when is_map(model) do
      %{
        screen: :home,
        layout: :vertical,
        widgets: [
          %{type: :header, text: model.title},
          %{type: :paragraph, text: model.tagline},
          %{type: :list, title: "Sites", items: model.sites},
          %{
            type: :stats,
            title: "Local Runtime",
            items: ["processes: #{model.process_count}", "jobs: #{model.job_count}"]
          }
        ]
      }
    end
  end

  @spec initial_shell_state() :: Shell.State.t()
  def initial_shell_state, do: Shell.new()
end
