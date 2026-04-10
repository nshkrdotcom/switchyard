defmodule Switchyard.CLITest do
  use ExUnit.Case, async: false

  alias Switchyard.CLI
  alias Switchyard.Daemon
  alias Switchyard.Site.{JidoHive, Local}

  setup do
    {:ok, daemon} =
      start_supervised({Daemon, site_modules: [Local, JidoHive], name: nil})

    %{daemon: daemon}
  end

  test "lists sites", %{daemon: daemon} do
    assert {:ok, sites} = CLI.run(["sites"], daemon: daemon)
    assert Enum.any?(sites, &(&1.id == "local"))
    assert Enum.any?(sites, &(&1.id == "jido-hive"))
  end

  test "lists apps for a site", %{daemon: daemon} do
    assert {:ok, apps} = CLI.run(["apps", "jido-hive"], daemon: daemon)
    assert Enum.any?(apps, &(&1.id == "jido-hive.rooms"))
  end

  test "returns the local snapshot", %{daemon: daemon} do
    assert {:ok, snapshot} = CLI.run(["local", "snapshot"], daemon: daemon)
    assert snapshot == %{jobs: [], processes: []}
  end

  test "rejects unknown commands", %{daemon: daemon} do
    assert {:error, _message} = CLI.run(["bogus"], daemon: daemon)
  end
end
