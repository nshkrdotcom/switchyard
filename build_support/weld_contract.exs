defmodule Switchyard.Build.WeldContract do
  @moduledoc false

  @artifact_docs [
    "README.md",
    "guides/index.md",
    "guides/vision.md",
    "guides/monorepo_strategy.md"
  ]

  def manifest do
    [
      workspace: [
        root: ".."
      ],
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
      roots: ["."],
      package: [
        name: "switchyard_workspace",
        otp_app: :switchyard_workspace,
        version: "0.1.0",
        description: "Workspace root artifact generated from the Switchyard monorepo",
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
