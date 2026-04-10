defmodule Switchyard.TUITest do
  use ExUnit.Case, async: true

  alias Switchyard.TUI
  alias Switchyard.TUI.HomeScreen

  test "builds a home screen view model" do
    model =
      HomeScreen.view_model(
        %{processes: [%{id: "proc-1"}], jobs: [%{id: "job-1"}, %{id: "job-2"}]},
        [%{title: "Local"}, %{title: "Jido Hive"}]
      )

    assert model.title == "Switchyard"
    assert model.sites == ["Local", "Jido Hive"]
    assert model.process_count == 1
    assert model.job_count == 2
  end

  test "builds a draw spec from the home screen model" do
    spec =
      %{title: "Switchyard", tagline: "ops", sites: ["Local"], process_count: 1, job_count: 0}
      |> HomeScreen.draw_spec()

    assert spec.screen == :home
    assert Enum.any?(spec.widgets, &(&1.type == :list and &1.title == "Sites"))
  end

  test "exposes the initial shell state" do
    assert %{route: :home} = TUI.initial_shell_state()
  end
end
