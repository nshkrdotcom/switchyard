defmodule Switchyard.Workspace do
  @moduledoc """
  Workspace-root marker module for the Switchyard monorepo.

  The root project is intentionally thin. It exists to host documentation,
  workspace orchestration, and shared build tooling above child Mix projects.
  """

  @doc """
  Returns the workspace identity tuple used by simple smoke tests.
  """
  @spec identity() :: {:ok, :switchyard_workspace}
  def identity do
    {:ok, :switchyard_workspace}
  end
end
