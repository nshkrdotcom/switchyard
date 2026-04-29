defmodule Switchyard.Examples.FutureRecoveryRedTest do
  use ExUnit.Case, async: true

  @moduletag :future_red

  test "future recovery reconnects only when a transport proves reconnect support" do
    flunk("""
    Future red test: implement when a specific execution transport can prove
    reconnect semantics. Until then, running process records must recover as
    lost audit records.
    """)
  end
end
