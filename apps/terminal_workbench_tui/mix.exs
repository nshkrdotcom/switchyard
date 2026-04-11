unless Code.ensure_loaded?(Switchyard.Build.DependencyResolver) do
  Code.require_file("../../build_support/dependency_resolver.exs", __DIR__)
end

defmodule Switchyard.TUI.MixProject do
  use Mix.Project

  alias Switchyard.Build.DependencyResolver

  def project do
    [
      app: :switchyard_tui,
      name: "Switchyard TUI",
      description: "Terminal host application for the Switchyard operator workbench",
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      escript: [
        app: nil,
        include_priv_for: [:ex_ratatui],
        main_module: Switchyard.TUI.CLI,
        name: "switchyard"
      ],
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:mix],
        plt_local_path: "priv/plts",
        ignore_warnings: Path.expand("../../dialyzer.ignore.exs", __DIR__)
      ],
      docs: [
        main: "readme",
        extras: ["README.md"],
        source_ref: "main",
        source_url: "https://github.com/nshkrdotcom/switchyard"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Switchyard.TUI.Application, []}
    ]
  end

  def cli do
    [preferred_envs: preferred_cli_env()]
  end

  defp deps do
    [
      DependencyResolver.switchyard_contracts(),
      DependencyResolver.switchyard_platform(),
      DependencyResolver.switchyard_shell(),
      DependencyResolver.switchyard_daemon(),
      DependencyResolver.switchyard_transport_local(),
      DependencyResolver.switchyard_site_local(),
      DependencyResolver.ex_ratatui(),
      {:credo, "~> 1.7.18", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end

  defp preferred_cli_env, do: [credo: :test, dialyzer: :dev, docs: :dev]
end
