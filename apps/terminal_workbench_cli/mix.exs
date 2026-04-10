unless Code.ensure_loaded?(Switchyard.Build.DependencyResolver) do
  Code.require_file("../../build_support/dependency_resolver.exs", __DIR__)
end

defmodule Switchyard.CLI.MixProject do
  use Mix.Project

  alias Switchyard.Build.DependencyResolver

  def project do
    [
      app: :switchyard_cli,
      name: "Switchyard CLI",
      description: "Headless CLI for inspecting and driving a local Switchyard daemon",
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: Switchyard.CLI],
      preferred_cli_env: preferred_cli_env(),
      dialyzer: [plt_add_apps: [:mix], plt_local_path: "priv/plts"],
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
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      DependencyResolver.switchyard_contracts(),
      DependencyResolver.switchyard_daemon(),
      DependencyResolver.switchyard_transport_local(),
      DependencyResolver.switchyard_site_local(),
      DependencyResolver.switchyard_site_jido_hive(),
      DependencyResolver.jason(),
      {:credo, "~> 1.7.18", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end

  defp preferred_cli_env, do: [credo: :test, dialyzer: :dev, docs: :dev]
end
