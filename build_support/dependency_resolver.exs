defmodule Switchyard.Build.DependencyResolver do
  @moduledoc false

  @repo_root Path.expand("..", __DIR__)
  @execution_plane_process_version "~> 0.1.0"
  @execution_plane_operator_terminal_version "~> 0.1.0"

  def switchyard_contracts(opts \\ []),
    do: resolve_internal(:switchyard_contracts, "core/workbench_contracts", opts)

  def switchyard_platform(opts \\ []),
    do: resolve_internal(:switchyard_platform, "core/workbench_platform", opts)

  def switchyard_daemon(opts \\ []),
    do: resolve_internal(:switchyard_daemon, "core/workbench_daemon", opts)

  def switchyard_transport_local(opts \\ []),
    do: resolve_internal(:switchyard_transport_local, "core/workbench_transport_local", opts)

  def switchyard_process_runtime(opts \\ []),
    do: resolve_internal(:switchyard_process_runtime, "core/workbench_process_runtime", opts)

  def switchyard_log_runtime(opts \\ []),
    do: resolve_internal(:switchyard_log_runtime, "core/workbench_log_runtime", opts)

  def switchyard_job_runtime(opts \\ []),
    do: resolve_internal(:switchyard_job_runtime, "core/workbench_job_runtime", opts)

  def switchyard_store_local(opts \\ []),
    do: resolve_internal(:switchyard_store_local, "core/workbench_store_local", opts)

  def switchyard_shell(opts \\ []),
    do: resolve_internal(:switchyard_shell, "core/workbench_shell_core", opts)

  def switchyard_node_ir(opts \\ []),
    do: resolve_internal(:workbench_node_ir, "core/workbench_node_ir", opts)

  def switchyard_tui_framework(opts \\ []),
    do: resolve_internal(:workbench_tui_framework, "core/workbench_tui_framework", opts)

  def switchyard_widgets(opts \\ []),
    do: resolve_internal(:workbench_widgets, "core/workbench_widgets", opts)

  def switchyard_devtools(opts \\ []),
    do: resolve_internal(:workbench_devtools, "core/workbench_devtools", opts)

  def switchyard_site_local(opts \\ []),
    do: resolve_internal(:switchyard_site_local, "sites/site_local", opts)

  def switchyard_site_execution_plane(opts \\ []),
    do: resolve_internal(:switchyard_site_execution_plane, "sites/site_execution_plane", opts)

  def switchyard_site_jido(opts \\ []),
    do: resolve_internal(:switchyard_site_jido, "sites/site_jido", opts)

  def switchyard_tui(opts \\ []),
    do: resolve_internal(:switchyard_tui, "apps/terminal_workbench_tui", opts)

  def switchyard_cli(opts \\ []),
    do: resolve_internal(:switchyard_cli, "apps/terminal_workbench_cli", opts)

  def switchyard_daemon_app(opts \\ []),
    do: resolve_internal(:switchyard_daemon_app, "apps/terminal_workbenchd", opts)

  def blitz(opts \\ []) do
    resolve_external(
      :blitz,
      local_root_path("../blitz"),
      "~> 0.2.0",
      opts
    )
  end

  def ex_ratatui(opts \\ []), do: {:ex_ratatui, "~> 0.8.1", opts}

  def execution_plane_process(opts \\ []) do
    resolve_external(
      :execution_plane_process,
      local_root_path("../execution_plane/runtimes/execution_plane_process"),
      @execution_plane_process_version,
      opts
    )
  end

  def execution_plane_operator_terminal(opts \\ []) do
    resolve_external(
      :execution_plane_operator_terminal,
      local_root_path("../execution_plane/runtimes/execution_plane_operator_terminal"),
      @execution_plane_operator_terminal_version,
      opts
    )
  end

  def jido_integration_v2(opts \\ []) do
    resolve_external(
      :jido_integration_v2,
      local_root_path("../jido_integration/core/platform"),
      [],
      opts
    )
  end

  def jason(opts \\ []) do
    {:jason, "~> 1.4", opts}
  end

  def nimble_options(opts \\ []) do
    {:nimble_options, "~> 1.1", opts}
  end

  def repo_root, do: @repo_root

  defp resolve_internal(app, subdir, opts) do
    case internal_workspace_path(subdir) do
      nil -> {app, [path: Path.expand(subdir, @repo_root)] ++ opts}
      path -> {app, Keyword.merge([path: path], opts)}
    end
  end

  defp resolve_external(app, path, requirement_or_opts, opts) do
    case existing_path(path) do
      nil ->
        build_external_dependency(app, requirement_or_opts, opts)

      resolved_path ->
        {app, Keyword.merge([path: resolved_path], opts)}
    end
  end

  defp build_external_dependency(app, requirement_or_opts, opts)
       when is_list(requirement_or_opts) do
    if Keyword.keyword?(requirement_or_opts) do
      {app, Keyword.merge(requirement_or_opts, opts)}
    else
      {app, requirement_or_opts, opts}
    end
  end

  defp build_external_dependency(app, requirement_or_opts, opts),
    do: {app, requirement_or_opts, opts}

  defp internal_workspace_path(subdir) do
    Path.join(@repo_root, subdir)
    |> existing_path()
  end

  defp local_root_path(default_relative_path) do
    if local_workspace_deps?() do
      default_relative_path
      |> Path.expand(@repo_root)
      |> existing_path()
    end
  end

  defp local_workspace_deps?, do: not Enum.member?(Path.split(@repo_root), "deps")

  defp existing_path(nil), do: nil

  defp existing_path(path) do
    expanded_path = Path.expand(path)

    if File.dir?(expanded_path) do
      expanded_path
    else
      nil
    end
  end
end
