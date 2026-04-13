defmodule Switchyard.Contracts.ActionResult do
  @moduledoc "Typed action execution result."

  alias Switchyard.Contracts

  @enforce_keys [:status, :message]
  defstruct status: nil, message: nil, job_id: nil, resource_ref: nil, output: nil

  @type t :: %__MODULE__{
          status: atom(),
          message: String.t(),
          job_id: String.t() | nil,
          resource_ref: term() | nil,
          output: term()
        }

  @spec new!(map()) :: t()
  def new!(attrs) do
    attrs = Contracts.fetch_required!(attrs, [:status, :message])
    struct!(__MODULE__, attrs)
  end
end
