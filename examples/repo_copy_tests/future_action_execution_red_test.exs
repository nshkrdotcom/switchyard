defmodule Switchyard.Examples.FutureActionExecutionRedTest do
  use ExUnit.Case, async: true

  @moduletag :future_red

  test "future action execution supports async provider-owned action jobs" do
    flunk("""
    Future red test: implement when provider-owned actions can return durable
    async job handles with progress and result polling through the daemon.
    """)
  end
end
