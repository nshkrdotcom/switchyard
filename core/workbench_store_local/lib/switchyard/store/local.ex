defmodule Switchyard.Store.Local do
  @moduledoc """
  Filesystem-backed JSON persistence primitives for local daemon state.

  The module provides a small, explicit store surface:

  - compatibility bucket/key JSON snapshots
  - daemon manifests
  - versioned snapshots under `snapshots/`
  - JSONL journals under `journals/`

  Readers return explicit malformed-data errors for versioned snapshots and
  journals so daemon recovery can fail closed instead of silently dropping
  corrupt state.
  """

  @schema_version 1

  @spec put_snapshot(Path.t(), String.t(), String.t(), map()) :: :ok
  def put_snapshot(root, bucket, key, value)
      when is_binary(root) and is_binary(bucket) and is_binary(key) and is_map(value) do
    write_json!(file_path(root, bucket, key), value)
    :ok
  end

  @spec get_snapshot(Path.t(), String.t(), String.t()) :: {:ok, map()} | :error
  def get_snapshot(root, bucket, key)
      when is_binary(root) and is_binary(bucket) and is_binary(key) do
    case File.read(file_path(root, bucket, key)) do
      {:ok, contents} -> {:ok, Jason.decode!(contents)}
      {:error, :enoent} -> :error
    end
  end

  @spec put_manifest(Path.t(), String.t(), map()) :: :ok
  def put_manifest(root, namespace, manifest)
      when is_binary(root) and is_binary(namespace) and is_map(manifest) do
    write_json!(manifest_path(root, namespace), manifest)
    :ok
  end

  @spec get_manifest(Path.t(), String.t()) :: {:ok, map()} | :error | {:error, term()}
  def get_manifest(root, namespace) when is_binary(root) and is_binary(namespace) do
    read_json(manifest_path(root, namespace), :malformed_manifest)
  end

  @spec put_versioned_snapshot(Path.t(), String.t(), String.t(), map()) :: :ok
  def put_versioned_snapshot(root, namespace, key, snapshot)
      when is_binary(root) and is_binary(namespace) and is_binary(key) and is_map(snapshot) do
    write_json!(snapshot_path(root, namespace, key), snapshot)
    :ok
  end

  @spec get_versioned_snapshot(Path.t(), String.t(), String.t()) ::
          {:ok, map()} | :error | {:error, term()}
  def get_versioned_snapshot(root, namespace, key)
      when is_binary(root) and is_binary(namespace) and is_binary(key) do
    with {:ok, snapshot} <- read_json(snapshot_path(root, namespace, key), :malformed_snapshot) do
      migrate_snapshot(snapshot)
    end
  end

  @spec append_journal(Path.t(), String.t(), String.t(), map()) :: :ok
  def append_journal(root, namespace, key, event)
      when is_binary(root) and is_binary(namespace) and is_binary(key) and is_map(event) do
    path = journal_path(root, namespace, key)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, [Jason.encode_to_iodata!(event), ?\n], [:append])
    :ok
  end

  @spec read_journal(Path.t(), String.t(), String.t()) ::
          {:ok, [map()]} | :error | {:error, term()}
  def read_journal(root, namespace, key)
      when is_binary(root) and is_binary(namespace) and is_binary(key) do
    case File.read(journal_path(root, namespace, key)) do
      {:ok, contents} -> decode_journal(contents)
      {:error, :enoent} -> :error
      {:error, reason} -> {:error, reason}
    end
  end

  @spec list_keys(Path.t(), String.t()) :: [String.t()]
  def list_keys(root, bucket) when is_binary(root) and is_binary(bucket) do
    case File.ls(bucket_path(root, bucket)) do
      {:ok, entries} ->
        entries
        |> Enum.filter(&String.ends_with?(&1, ".json"))
        |> Enum.map(&String.replace_suffix(&1, ".json", ""))
        |> Enum.sort()

      {:error, :enoent} ->
        []
    end
  end

  defp bucket_path(root, bucket), do: Path.join([root, bucket])
  defp file_path(root, bucket, key), do: Path.join([root, bucket, key <> ".json"])

  defp manifest_path(root, namespace), do: Path.join([root, namespace, "manifest.json"])

  defp snapshot_path(root, namespace, key),
    do: Path.join([root, namespace, "snapshots", key <> ".json"])

  defp journal_path(root, namespace, key),
    do: Path.join([root, namespace, "journals", key <> ".jsonl"])

  defp write_json!(path, value) do
    File.mkdir_p!(Path.dirname(path))

    tmp_path = path <> ".tmp-#{System.unique_integer([:positive])}"
    File.write!(tmp_path, Jason.encode_to_iodata!(value, pretty: true))
    File.rename!(tmp_path, path)
  end

  defp read_json(path, error_tag) do
    case File.read(path) do
      {:ok, contents} ->
        case Jason.decode(contents) do
          {:ok, %{} = decoded} -> {:ok, decoded}
          {:ok, _other} -> {:error, {error_tag, :not_an_object}}
          {:error, reason} -> {:error, {error_tag, Exception.message(reason)}}
        end

      {:error, :enoent} ->
        :error

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp migrate_snapshot(%{"schema_version" => @schema_version} = snapshot), do: {:ok, snapshot}

  defp migrate_snapshot(%{"schema_version" => 0} = snapshot) do
    migration_entry = %{
      "from" => 0,
      "to" => @schema_version,
      "at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    migrated =
      snapshot
      |> Map.put("schema_version", @schema_version)
      |> Map.update("migration_history", [migration_entry], &[migration_entry | List.wrap(&1)])

    {:ok, migrated}
  end

  defp migrate_snapshot(%{"schema_version" => version}) do
    {:error, {:unsupported_schema_version, version}}
  end

  defp migrate_snapshot(_snapshot), do: {:error, :missing_schema_version}

  defp decode_journal(contents) do
    contents
    |> String.split("\n", trim: true)
    |> Enum.reduce_while({:ok, []}, fn line, {:ok, events} ->
      case Jason.decode(line) do
        {:ok, %{} = event} -> {:cont, {:ok, [event | events]}}
        {:ok, _other} -> {:halt, {:error, {:malformed_journal, :not_an_object}}}
        {:error, reason} -> {:halt, {:error, {:malformed_journal, Exception.message(reason)}}}
      end
    end)
    |> case do
      {:ok, events} -> {:ok, Enum.reverse(events)}
      error -> error
    end
  end
end
