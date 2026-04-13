defmodule Switchyard.Contracts do
  @moduledoc """
  Shared contract helpers for the Switchyard platform.
  """

  @spec fetch_required!(map(), [atom()]) :: map()
  def fetch_required!(attrs, keys) when is_map(attrs) and is_list(keys) do
    Enum.each(keys, fn key ->
      unless Map.has_key?(attrs, key) do
        raise ArgumentError, "missing required contract key #{inspect(key)}"
      end
    end)

    attrs
  end
end
