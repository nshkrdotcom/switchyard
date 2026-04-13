defmodule Switchyard.Contracts.SearchProvider do
  @moduledoc "Behaviour for search providers."

  alias Switchyard.Contracts.SearchResult

  @callback search(String.t(), map()) :: [SearchResult.t()]
end
