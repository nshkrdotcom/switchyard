defmodule Switchyard.Build.PackageDocs do
  @moduledoc false

  @source_url "https://github.com/nshkrdotcom/switchyard"

  @spec docs(keyword()) :: keyword()
  def docs(opts) do
    package_title = Keyword.fetch!(opts, :package_title)
    root_prefix = Keyword.get(opts, :root_prefix, "../..")

    [
      main: "readme",
      homepage_url: @source_url,
      source_ref: "main",
      source_url: @source_url,
      extras: extras(package_title, root_prefix),
      groups_for_extras: groups_for_extras(root_prefix)
    ]
  end

  defp extras(package_title, root_prefix) do
    [
      {"README.md", filename: "readme", title: "#{package_title} Overview"},
      {Path.join(root_prefix, "README.md"),
       filename: "workspace_readme", title: "Workspace Overview"},
      {Path.join(root_prefix, "guides/index.md"), filename: "guide_index", title: "Guide Index"},
      {Path.join(root_prefix, "guides/current_state.md"),
       filename: "current_state", title: "Current State"},
      {Path.join(root_prefix, "guides/vision.md"), filename: "vision", title: "Vision"},
      {Path.join(root_prefix, "guides/monorepo_strategy.md"),
       filename: "monorepo_strategy", title: "Monorepo Strategy"},
      {Path.join(root_prefix, "guides/package_boundaries.md"),
       filename: "package_boundaries", title: "Package Boundaries"},
      {Path.join(root_prefix, "guides/runtime_model.md"),
       filename: "runtime_model", title: "Runtime Model"},
      {Path.join(root_prefix, "guides/workspace_workflow.md"),
       filename: "workspace_workflow", title: "Workspace Workflow"},
      {Path.join(root_prefix, "guides/testing_and_delivery.md"),
       filename: "testing_and_delivery", title: "Testing And Delivery"},
      {Path.join(root_prefix, "docs/implementation_checklist.md"),
       filename: "implementation_checklist", title: "Implementation Checklist"},
      {Path.join(root_prefix, "CHANGELOG.md"), filename: "changelog", title: "Changelog"},
      {Path.join(root_prefix, "LICENSE"), filename: "license", title: "License"}
    ]
  end

  defp groups_for_extras(root_prefix) do
    [
      Package: ["README.md"],
      Overview: [
        Path.join(root_prefix, "README.md"),
        Path.join(root_prefix, "guides/index.md"),
        Path.join(root_prefix, "guides/current_state.md"),
        Path.join(root_prefix, "guides/vision.md")
      ],
      Architecture: [
        Path.join(root_prefix, "guides/monorepo_strategy.md"),
        Path.join(root_prefix, "guides/package_boundaries.md"),
        Path.join(root_prefix, "guides/runtime_model.md")
      ],
      Workflow: [
        Path.join(root_prefix, "guides/workspace_workflow.md"),
        Path.join(root_prefix, "guides/testing_and_delivery.md")
      ],
      Delivery: [
        Path.join(root_prefix, "docs/implementation_checklist.md"),
        Path.join(root_prefix, "CHANGELOG.md")
      ],
      Project: [Path.join(root_prefix, "LICENSE")]
    ]
  end
end
