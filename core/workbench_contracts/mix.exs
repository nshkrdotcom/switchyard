unless Code.ensure_loaded?(Switchyard.Build.PackageDocs) do
  Code.require_file("../../build_support/package_docs.exs", __DIR__)
end

defmodule Switchyard.Contracts.MixProject do
  use Mix.Project

  alias Switchyard.Build.PackageDocs

  def project do
    [
      app: :switchyard_contracts,
      name: "Switchyard Contracts",
      description:
        "Typed platform contracts for Switchyard sites, apps, resources, actions, jobs, and logs",
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
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
      {:credo, "~> 1.7.18", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end

  defp preferred_cli_env, do: [credo: :test, dialyzer: :dev, docs: :dev]

  defp dialyzer do
    [plt_add_apps: [:mix], plt_local_path: "priv/plts"]
  end

  defp docs do
    PackageDocs.docs(package_title: "Switchyard Contracts")
  end
end
