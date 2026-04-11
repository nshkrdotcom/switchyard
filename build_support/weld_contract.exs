defmodule Switchyard.Build.WeldContract do
  @moduledoc false

  @artifact_docs [
    "README.md",
    "guides/index.md",
    "guides/vision.md",
    "guides/monorepo_strategy.md",
    "guides/package_boundaries.md",
    "guides/runtime_model.md",
    "guides/testing_and_delivery.md",
    "docs/implementation_checklist.md",
    "LICENSE"
  ]

  @dependencies [
    blitz: [requirement: "~> 0.2.0"],
    weld: [requirement: "~> 0.4.0"]
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
        "sites/site_local"
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
      ]
    ]
  end
end
