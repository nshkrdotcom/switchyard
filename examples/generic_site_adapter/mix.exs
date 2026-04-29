defmodule GenericSiteAdapter.MixProject do
  use Mix.Project

  def project do
    [
      app: :generic_site_adapter,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    root = switchyard_root!()

    [
      {:switchyard_contracts, path: Path.join(root, "core/workbench_contracts")},
      {:switchyard_platform, path: Path.join(root, "core/workbench_platform")}
    ]
  end

  defp switchyard_root! do
    System.get_env("SWITCHYARD_ROOT") ||
      raise """
      SWITCHYARD_ROOT is required.

      Run with:

          SWITCHYARD_ROOT=/path/to/switchyard mix test
      """
  end
end
