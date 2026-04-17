unless Code.ensure_loaded?(Switchyard.Build.DependencyResolver) do
  Code.require_file("../../build_support/dependency_resolver.exs", __DIR__)
end

unless Code.ensure_loaded?(Switchyard.Build.PackageDocs) do
  Code.require_file("../../build_support/package_docs.exs", __DIR__)
end

defmodule Switchyard.Site.Jido.MixProject do
  use Mix.Project

  alias Switchyard.Build.{DependencyResolver, PackageDocs}

  def project do
    [
      app: :switchyard_site_jido,
      name: "Switchyard Site Jido",
      description: "Durable Jido operator site for the Switchyard workbench",
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix], plt_local_path: "priv/plts"],
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [preferred_envs: preferred_cli_env()]
  end

  defp deps do
    [
      DependencyResolver.switchyard_contracts(),
      DependencyResolver.execution_plane(),
      DependencyResolver.jido_integration_v2(),
      {:credo, "~> 1.7.18", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end

  defp preferred_cli_env, do: [credo: :test, dialyzer: :dev, docs: :dev]

  defp docs do
    PackageDocs.docs(package_title: "Switchyard Site Jido")
  end
end
