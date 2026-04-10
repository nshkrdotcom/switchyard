defmodule Switchyard.DaemonAppTest do
  use ExUnit.Case, async: true

  test "declares the installed site modules" do
    assert Switchyard.DaemonApp.site_modules() == [
             Switchyard.Site.Local,
             Switchyard.Site.JidoHive
           ]
  end
end
