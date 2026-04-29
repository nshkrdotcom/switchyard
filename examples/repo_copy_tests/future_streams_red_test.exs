defmodule Switchyard.Examples.FutureStreamsRedTest do
  use ExUnit.Case, async: true

  @moduletag :future_red

  test "future streams support durable follow cursors across daemon restarts" do
    flunk("""
    Future red test: implement when file-backed stream retention and follow
    cursors are available through the daemon request path.
    """)
  end
end
