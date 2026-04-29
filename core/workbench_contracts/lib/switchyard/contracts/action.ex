defmodule Switchyard.Contracts.Action do
  @moduledoc "Typed action contract."

  alias Switchyard.Contracts

  @enforce_keys [:id, :title, :scope, :provider]
  defstruct id: nil,
            title: nil,
            scope: nil,
            provider: nil,
            input_schema: %{},
            confirmation: :never

  @type scope ::
          {:global, atom() | String.t()}
          | {:site, String.t()}
          | {:app, String.t()}
          | {:resource, atom()}
          | {:resource_instance, String.t(), atom(), String.t()}

  @type confirmation :: :never | :if_destructive | :always

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          scope: scope(),
          provider: module(),
          input_schema: map(),
          confirmation: confirmation()
        }

  @spec new!(map()) :: t()
  def new!(attrs) do
    attrs = Contracts.fetch_required!(attrs, [:id, :title, :scope, :provider])
    struct!(__MODULE__, attrs)
  end
end
