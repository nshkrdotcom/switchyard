defmodule Switchyard.DaemonApp do
  @moduledoc """
  Runnable release wrapper for the Switchyard daemon.
  """

  @spec site_modules() :: [module()]
  def site_modules do
    [Switchyard.Site.Local, Switchyard.Site.JidoHive]
  end
end
