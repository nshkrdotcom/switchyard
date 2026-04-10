defmodule Switchyard.Build.WorkspaceContract do
  @moduledoc false

  @active_project_globs [
    ".",
    "core/*",
    "sites/*",
    "apps/*"
  ]

  def active_project_globs, do: @active_project_globs
end
