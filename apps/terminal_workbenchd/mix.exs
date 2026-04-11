unless Code.ensure_loaded?(Switchyard.Build.DependencyResolver) do
  Code.require_file("../../build_support/dependency_resolver.exs", __DIR__)
end

unless Code.ensure_loaded?(Switchyard.Build.PackageDocs) do
  Code.require_file("../../build_support/package_docs.exs", __DIR__)
end

defmodule Switchyard.DaemonApp.MixProject do
  use Mix.Project

  alias Switchyard.Build.{DependencyResolver, PackageDocs}

  def project do
    [
      app: :switchyard_daemon_app,
      name: "Switchyard Daemon App",
      description: "Runnable OTP application that starts the local Switchyard daemon",
      version: "0.1.0",
      elixir: "~> 1.19",
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
      extra_applications: [:logger],
      mod: {Switchyard.DaemonApp.Application, []}
    ]
  end

  def cli do
    [preferred_envs: preferred_cli_env()]
  end

  defp deps do
    [
      DependencyResolver.switchyard_daemon(),
      DependencyResolver.switchyard_site_local(),
      {:credo, "~> 1.7.18", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end

  defp preferred_cli_env, do: [credo: :test, dialyzer: :dev, docs: :dev]

  defp docs do
    PackageDocs.docs(package_title: "Switchyard Daemon App")
  end
end
