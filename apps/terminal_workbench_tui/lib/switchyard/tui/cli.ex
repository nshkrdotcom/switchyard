defmodule Switchyard.TUI.CLI do
  @moduledoc false

  require Logger

  alias Switchyard.TUI
  alias Switchyard.TUI.EscriptBootstrap

  @switches [
    debug: :boolean,
    debug_dir: :string,
    debug_history_limit: :integer,
    ssh: :boolean,
    ssh_port: :integer,
    ssh_user: :string,
    ssh_password: :string,
    distributed: :boolean
  ]

  @spec main([String.t()]) :: no_return()
  def main(argv) do
    opts = parse_run_opts(argv)

    if Keyword.get(opts, :log_level) == "debug" do
      Logger.configure(level: :debug)
    end

    case EscriptBootstrap.start_tui_dependencies() do
      :ok ->
        case TUI.run(opts) do
          :ok ->
            System.halt(0)

          {:error, reason} ->
            IO.puts(:stderr, "Switchyard TUI failed: #{inspect(reason)}")
            System.halt(1)
        end

      {:error, reason} ->
        IO.puts(:stderr, "Switchyard TUI bootstrap failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  @spec parse_run_opts([String.t()]) :: keyword()
  def parse_run_opts(argv) do
    {opts, _args, _invalid} = OptionParser.parse(argv, strict: @switches)

    []
    |> maybe_debug_opts(opts)
    |> maybe_transport_opts(opts)
  end

  defp maybe_debug_opts(run_opts, opts) do
    if Keyword.get(opts, :debug, false) do
      (run_opts ++
         [
           debug: true,
           log_level: "debug",
           debug_dir: Keyword.get(opts, :debug_dir),
           debug_history_limit: Keyword.get(opts, :debug_history_limit)
         ])
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    else
      run_opts
    end
  end

  defp maybe_transport_opts(run_opts, opts) do
    cond do
      Keyword.get(opts, :ssh, false) ->
        ssh_user = Keyword.get(opts, :ssh_user, "demo")
        ssh_password = Keyword.get(opts, :ssh_password, "demo")

        run_opts ++
          [
            transport: :ssh,
            port: Keyword.get(opts, :ssh_port, 2222),
            auto_host_key: true,
            auth_methods: ~c"password",
            user_passwords: [{String.to_charlist(ssh_user), String.to_charlist(ssh_password)}]
          ]

      Keyword.get(opts, :distributed, false) ->
        run_opts ++ [transport: :distributed]

      true ->
        run_opts
    end
  end
end
