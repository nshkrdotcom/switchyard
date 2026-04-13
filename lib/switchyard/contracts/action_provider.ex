defmodule Switchyard.Contracts.ActionProvider do
  @moduledoc "Behaviour for executable action providers."

  alias Switchyard.Contracts.{Action, ActionResult}

  @callback action_definition() :: Action.t()
  @callback execute(map(), map()) :: {:ok, ActionResult.t()} | {:error, term()}
end
