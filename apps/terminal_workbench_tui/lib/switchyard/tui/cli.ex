defmodule Switchyard.TUI.CLI do
  @moduledoc false

  require Logger

  alias Switchyard.TUI
  alias Switchyard.TUI.EscriptBootstrap

  @switches [debug: :boolean, debug_dir: :string, debug_history_limit: :integer]

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

    if Keyword.get(opts, :debug, false) do
      [
        debug: true,
        log_level: "debug",
        debug_dir: Keyword.get(opts, :debug_dir),
        debug_history_limit: Keyword.get(opts, :debug_history_limit)
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    else
      []
    end
  end
end
