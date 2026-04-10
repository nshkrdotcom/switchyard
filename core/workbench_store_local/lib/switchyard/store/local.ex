defmodule Switchyard.Store.Local do
  @moduledoc """
  Filesystem-backed JSON persistence for local daemon state.
  """

  @spec put_snapshot(Path.t(), String.t(), String.t(), map()) :: :ok
  def put_snapshot(root, bucket, key, value)
      when is_binary(root) and is_binary(bucket) and is_binary(key) and is_map(value) do
    root
    |> bucket_path(bucket)
    |> File.mkdir_p!()

    root
    |> file_path(bucket, key)
    |> File.write!(Jason.encode_to_iodata!(value, pretty: true))

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
end
