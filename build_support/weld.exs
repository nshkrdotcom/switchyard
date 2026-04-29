defmodule Switchyard.Build.WeldContract do
  @moduledoc false

  @repo_root Path.expand("..", __DIR__)
  @execution_plane_repo_path Path.expand("../execution_plane", @repo_root)
  @jido_integration_repo_path Path.expand("../jido_integration", @repo_root)

  @artifact_docs [
    "README.md",
    "guides/index.md",
    "guides/current_state.md",
    "guides/vision.md",
    "guides/monorepo_strategy.md",
    "guides/package_boundaries.md",
    "guides/runtime_model.md",
    "guides/workspace_workflow.md",
    "guides/testing_and_delivery.md",
    "docs/implementation_checklist.md",
    "LICENSE"
  ]

  @dependencies [
    blitz: [requirement: "~> 0.2.0"],
    execution_plane: [
      opts:
        if File.dir?(@execution_plane_repo_path) do
          [git: @execution_plane_repo_path]
        else
          [github: "nshkrdotcom/execution_plane", branch: "main"]
        end
    ],
    execution_plane_operator_terminal: [
      opts:
        if File.dir?(@execution_plane_repo_path) do
          [
            git: @execution_plane_repo_path,
            sparse: "runtimes/execution_plane_operator_terminal"
          ]
        else
          [
            github: "nshkrdotcom/execution_plane",
            branch: "main",
            sparse: "runtimes/execution_plane_operator_terminal"
          ]
        end
    ],
    jido_integration_v2: [
      opts:
        if File.dir?(@jido_integration_repo_path) do
          [
            git: @jido_integration_repo_path,
            sparse: "core/platform"
          ]
        else
          [
            github: "nshkrdotcom/jido_integration",
            branch: "main",
            sparse: "core/platform"
          ]
        end
    ],
    weld: [requirement: "~> 0.7.2"],
    ex_ratatui: [requirement: "~> 0.8.1"]
  ]

  def manifest do
    [
      workspace: [
        root: ".."
      ],
      dependencies: @dependencies,
      classify: [
        tooling: ["."]
      ],
      publication: [
        internal_only: ["."]
      ],
      artifacts: [
        switchyard: artifact()
      ]
    ]
  end

  def artifact do
    [
      mode: :monolith,
      roots: [
        "core/workbench_contracts",
        "core/workbench_platform",
        "core/workbench_daemon",
        "core/workbench_transport_local",
        "core/workbench_process_runtime",
        "core/workbench_log_runtime",
        "core/workbench_job_runtime",
        "core/workbench_store_local",
        "core/workbench_shell_core",
        "core/workbench_tui_framework",
        "core/workbench_widgets",
        "core/workbench_devtools",
        "sites/site_local",
        "sites/site_execution_plane",
        "sites/site_jido"
      ],
      package: [
        name: "switchyard_foundation",
        otp_app: :switchyard_foundation,
        version: "0.1.0",
        description:
          "Foundation monolith generated from the Switchyard terminal workbench monorepo",
        licenses: ["MIT"],
        maintainers: ["nshkrdotcom"],
        links: %{
          "GitHub" => "https://github.com/nshkrdotcom/switchyard",
          "Guides" => "https://hexdocs.pm/switchyard_workspace/workspace_readme.html"
        }
      ],
      output: [
        docs: @artifact_docs,
        assets: ["assets/switchyard.svg", "CHANGELOG.md", "LICENSE"]
      ],
      verify: [
        hex_build: false,
        hex_publish: false
      ]
    ]
  end
end

Switchyard.Build.WeldContract.manifest()
