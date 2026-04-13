defmodule SwitchyardFoundation.MixProject do
  use Mix.Project

  def project do
    [
      app: :switchyard_foundation,
      version: "0.1.0",
      build_path: "_build",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      erlc_paths: [],
      deps: deps(),
      description:
        "Foundation monolith generated from the Switchyard terminal workbench monorepo",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [mod: {SwitchyardFoundation.Application, []}, extra_applications: [:logger]]
  end

  def elixirc_paths(:test) do
    if File.dir?("test/support") do
      ["lib", "test/support"]
    else
      ["lib"]
    end
  end

  def elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:ex_ratatui, "~> 0.7.0", []},
      {:file_system, "~> 1.1"},
      {:jason, "~> 1.4", []},
      {:nimble_options, "~> 1.1", []},
      {:telemetry, "~> 1.2"},
      {:credo, "~> 1.7.18", [only: [:dev, :test], runtime: false]},
      {:dialyxir, "~> 1.4.7", [only: [:dev, :test], runtime: false]},
      {:ex_doc, "~> 0.40.1", [only: :dev, runtime: false]}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["nshkrdotcom"],
      links: %{
        "GitHub" => "https://github.com/nshkrdotcom/switchyard",
        "Guides" => "https://hexdocs.pm/switchyard_workspace/workspace_readme.html"
      },
      files: [
        ".formatter.exs",
        "LICENSE",
        "README.md",
        "config",
        "docs",
        "guides",
        "lib",
        "mix.exs",
        "priv",
        "projection.lock.json"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "LICENSE",
        "README.md",
        "docs/implementation_checklist.md",
        "guides/current_state.md",
        "guides/index.md",
        "guides/monorepo_strategy.md",
        "guides/package_boundaries.md",
        "guides/runtime_model.md",
        "guides/testing_and_delivery.md",
        "guides/vision.md",
        "guides/workspace_workflow.md"
      ]
    ]
  end
end
