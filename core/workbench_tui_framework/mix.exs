unless Code.ensure_loaded?(Switchyard.Build.DependencyResolver) do
  Code.require_file("../../build_support/dependency_resolver.exs", __DIR__)
end

unless Code.ensure_loaded?(Switchyard.Build.PackageDocs) do
  Code.require_file("../../build_support/package_docs.exs", __DIR__)
end

defmodule WorkbenchTuiFramework.MixProject do
  use Mix.Project

  alias Switchyard.Build.{DependencyResolver, PackageDocs}

  def project do
    [
      app: :workbench_tui_framework,
      name: "Workbench TUI Framework",
      description:
        "Greenfield BEAM-native terminal UI runtime and rendering framework for Switchyard",
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:mix],
        plt_local_path: "priv/plts",
        ignore_warnings: Path.expand("../../dialyzer.ignore.exs", __DIR__)
      ],
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [preferred_envs: [credo: :test, dialyzer: :dev, docs: :dev]]
  end

  defp deps do
    [
      DependencyResolver.ex_ratatui(),
      DependencyResolver.nimble_options(),
      {:telemetry, "~> 1.2"},
      {:credo, "~> 1.7.18", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end

  defp docs do
    PackageDocs.docs(package_title: "Workbench TUI Framework")
  end
end
