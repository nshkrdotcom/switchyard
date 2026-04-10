defmodule Switchyard.DaemonApp.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Switchyard.Daemon,
       name: Switchyard.Daemon.Server, site_modules: Switchyard.DaemonApp.site_modules()}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Switchyard.DaemonApp.Supervisor)
  end
end
