defmodule Switchyard.DaemonApp do
  @moduledoc """
  Runnable release wrapper for the Switchyard daemon.
  """

  @spec site_modules() :: [module()]
  def site_modules do
    [Switchyard.Site.ExecutionPlane, Switchyard.Site.Jido]
  end
end
