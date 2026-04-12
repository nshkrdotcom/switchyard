unless Code.ensure_loaded?(Switchyard.Build.DependencyResolver) do
  Code.require_file("build_support/dependency_resolver.exs", __DIR__)
end

unless Code.ensure_loaded?(Switchyard.Build.WorkspaceContract) do
  Code.require_file("build_support/workspace_contract.exs", __DIR__)
end

defmodule Switchyard.Workspace.MixProject do
  use Mix.Project

  alias Switchyard.Build.{DependencyResolver, WorkspaceContract}

  def project do
    [
      app: :switchyard_workspace,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      blitz_workspace: blitz_workspace(),
      dialyzer: dialyzer(),
      docs: docs(),
      name: "Switchyard Workspace",
      description: "Workspace root for the Switchyard non-umbrella terminal workbench monorepo"
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

  def blitz_workspace_env(%{root: root}) do
    repo_bin = Path.join(root, "bin")
    path = prepend_path(repo_bin, System.get_env("PATH"))

    [
      {"PATH", path},
      {"SSLKEYLOGFILE", nil}
    ]
  end

  def blitz_workspace_test_env(context), do: blitz_workspace_env(context)

  defp deps do
    [
      DependencyResolver.blitz(runtime: false),
      DependencyResolver.weld(runtime: false),
      {:credo, "~> 1.7.11", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    monorepo_aliases = [
      "monorepo.deps.get": ["blitz.workspace deps_get"],
      "monorepo.format": ["blitz.workspace format"],
      "monorepo.compile": ["blitz.workspace compile"],
      "monorepo.test": ["blitz.workspace test"],
      "monorepo.credo": ["blitz.workspace credo"],
      "monorepo.dialyzer": ["blitz.workspace dialyzer"],
      "monorepo.docs": ["blitz.workspace docs"]
    ]

    mr_aliases =
      ~w[deps.get format compile test credo dialyzer docs]
      |> Enum.map(fn task -> {:"mr.#{task}", ["monorepo.#{task}"]} end)

    [
      ci: [
        "monorepo.deps.get",
        "monorepo.format --check-formatted",
        "monorepo.compile",
        "monorepo.test",
        "monorepo.credo --strict",
        "monorepo.dialyzer",
        "monorepo.docs --warnings-as-errors"
      ],
      quality: ["monorepo.credo --strict", "monorepo.dialyzer"],
      "docs.all": ["monorepo.docs --warnings-as-errors"],
      "weld.inspect": ["weld.inspect build_support/weld.exs --artifact switchyard"],
      "weld.graph": ["weld.graph build_support/weld.exs --artifact switchyard"],
      "weld.project": ["weld.project build_support/weld.exs --artifact switchyard"],
      "weld.verify": ["weld.verify build_support/weld.exs --artifact switchyard"]
    ] ++ monorepo_aliases ++ mr_aliases
  end

  defp preferred_cli_env do
    [
      credo: :test,
      dialyzer: :dev,
      docs: :dev
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix, :blitz, :weld],
      plt_local_path: "priv/plts",
      flags: [:error_handling, :missing_return, :underspecs, :unknown]
    ]
  end

  defp docs do
    [
      main: "workspace_readme",
      logo: "assets/switchyard.svg",
      homepage_url: "https://github.com/nshkrdotcom/switchyard",
      source_url: "https://github.com/nshkrdotcom/switchyard",
      assets: %{"assets" => "assets"},
      extras: [
        {"README.md", filename: "workspace_readme", title: "Overview"},
        {"guides/index.md", title: "Guide Index"},
        {"guides/vision.md", title: "Vision"},
        {"guides/monorepo_strategy.md", title: "Monorepo Strategy"},
        {"guides/package_boundaries.md", title: "Package Boundaries"},
        {"guides/runtime_model.md", title: "Runtime Model"},
        {"guides/testing_and_delivery.md", title: "Testing And Delivery"},
        {"docs/implementation_checklist.md", title: "Implementation Checklist"},
        {"CHANGELOG.md", title: "Changelog"},
        {"LICENSE", title: "License"}
      ],
      groups_for_extras: [
        "Start Here": ~r/README.md|guides\/index.md|guides\/vision.md/,
        Architecture:
          ~r/guides\/monorepo_strategy.md|guides\/package_boundaries.md|guides\/runtime_model.md/,
        Execution: ~r/guides\/testing_and_delivery.md|docs\/implementation_checklist.md/,
        Project: ~r/CHANGELOG.md|LICENSE/
      ]
    ]
  end

  defp blitz_workspace do
    [
      root: __DIR__,
      projects: WorkspaceContract.active_project_globs(),
      isolation: [
        deps_path: true,
        build_path: true,
        lockfile: true,
        hex_home: "_build/hex",
        unset_env: ["HEX_API_KEY", "SSLKEYLOGFILE"]
      ],
      parallelism: [
        env: "SWITCHYARD_MAX_CONCURRENCY",
        multiplier: :auto,
        base: [
          deps_get: 2,
          format: 2,
          compile: 2,
          test: 2,
          credo: 1,
          dialyzer: 1,
          docs: 1
        ],
        overrides: []
      ],
      tasks: [
        deps_get: [
          args: ["deps.get"],
          preflight?: false,
          env: &__MODULE__.blitz_workspace_env/1
        ],
        format: [args: ["format"], env: &__MODULE__.blitz_workspace_env/1],
        compile: [
          args: ["compile", "--warnings-as-errors"],
          env: &__MODULE__.blitz_workspace_env/1
        ],
        test: [
          args: ["test"],
          mix_env: "test",
          color: true,
          env: &__MODULE__.blitz_workspace_test_env/1
        ],
        credo: [args: ["credo"], env: &__MODULE__.blitz_workspace_env/1],
        dialyzer: [
          args: ["dialyzer", "--force-check"],
          env: &__MODULE__.blitz_workspace_env/1
        ],
        docs: [
          args: ["docs"],
          env: &__MODULE__.blitz_workspace_env/1
        ]
      ]
    ]
  end

  defp prepend_path(dir, nil), do: dir
  defp prepend_path(dir, ""), do: dir
  defp prepend_path(dir, path), do: dir <> ":" <> path
end
