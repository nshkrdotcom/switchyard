defmodule Switchyard.TUI.CLI do
  @moduledoc false

  require Logger

  alias Switchyard.TUI

  @switches [debug: :boolean]

  @spec main([String.t()]) :: no_return()
  def main(argv) do
    opts = parse_run_opts(argv)

    if Keyword.get(opts, :log_level) == "debug" do
      Logger.configure(level: :debug)
    end

    case TUI.run(opts) do
      :ok ->
        System.halt(0)

      {:error, reason} ->
        IO.puts(:stderr, "Switchyard TUI failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  @spec parse_run_opts([String.t()]) :: keyword()
  def parse_run_opts(argv) do
    {opts, _args, _invalid} = OptionParser.parse(argv, strict: @switches)
    if Keyword.get(opts, :debug, false), do: [log_level: "debug"], else: []
  end
end
