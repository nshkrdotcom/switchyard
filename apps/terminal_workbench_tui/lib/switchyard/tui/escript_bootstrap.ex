defmodule Switchyard.TUI.EscriptBootstrap do
  @moduledoc false

  @ex_ratatui_archive_prefix "ex_ratatui/"
  @zip_name ~c"escript.zip"

  @spec start_tui_dependencies() :: :ok | {:error, term()}
  def start_tui_dependencies do
    ex_ratatui_dir = ex_ratatui_app_dir()
    ebin_dir = Path.join(ex_ratatui_dir, "ebin")
    native_dir = Path.join(ex_ratatui_dir, "priv/native")

    if File.dir?(ebin_dir) and File.dir?(native_dir) do
      add_code_path(ebin_dir)
    else
      with {:ok, archive} <- escript_archive(),
           :ok <- extract_ex_ratatui_app_from_archive(archive, ex_ratatui_dir),
           true <- File.dir?(ebin_dir),
           true <- File.dir?(native_dir),
           :ok <- add_code_path(ebin_dir) do
        :ok
      else
        {:error, :not_running_from_escript} -> :ok
        false -> {:error, {:missing_ex_ratatui_escript_files, ex_ratatui_dir}}
        {:error, _reason} = error -> error
      end
    end
  end

  defp escript_archive do
    script_name = :escript.script_name()

    with true <- is_list(script_name),
         {:ok, sections} <- :escript.extract(script_name, []),
         {:archive, archive} when is_binary(archive) <- List.keyfind(sections, :archive, 0) do
      {:ok, archive}
    else
      false -> {:error, :not_running_from_escript}
      {:error, _reason} = error -> error
      nil -> {:error, :not_running_from_escript}
    end
  end

  defp extract_ex_ratatui_app_from_archive(archive, ex_ratatui_dir) do
    File.rm_rf!(ex_ratatui_dir)
    File.mkdir_p!(ex_ratatui_dir)

    with {:ok, copied} <-
           copy_prefixed_archive_files_to_dir(archive, @ex_ratatui_archive_prefix, ex_ratatui_dir),
         true <- copied > 0 do
      :ok
    else
      false -> {:error, :missing_ex_ratatui_files_in_archive}
      {:error, _reason} = error -> error
    end
  end

  defp copy_prefixed_archive_files_to_dir(archive, prefix, target_dir) do
    :zip.foldl(
      fn name, _get_info, get_bin, copied ->
        archive_path = List.to_string(name)

        if String.starts_with?(archive_path, prefix) do
          relative_path = String.replace_prefix(archive_path, prefix, "")
          target_path = Path.join(target_dir, relative_path)
          File.mkdir_p!(Path.dirname(target_path))
          File.write!(target_path, get_bin.())
          copied + 1
        else
          copied
        end
      end,
      0,
      {@zip_name, archive}
    )
  end

  defp add_code_path(path) do
    case :code.add_patha(String.to_charlist(path)) do
      true -> :ok
      {:error, reason} -> {:error, {:code_path_add_failed, path, reason}}
    end
  end

  defp ex_ratatui_app_dir do
    Path.join([config_dir(), "escript_apps", "ex_ratatui"])
  end

  defp config_dir do
    Path.join([xdg_config_root(), "switchyard"])
  end

  defp xdg_config_root do
    System.get_env("XDG_CONFIG_HOME") || Path.join(System.user_home!(), ".config")
  end
end
