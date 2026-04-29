defmodule Switchyard.Examples.FutureProcessLifecycleRedTest do
  use ExUnit.Case, async: true

  @moduletag :future_red

  test "future process lifecycle supports safe restart from persisted restart specs" do
    flunk("""
    Future red test: implement when the daemon stores an explicitly safe
    restart spec and can restart a lost or stopped process without reusing
    unsafe raw runtime internals.
    """)
  end
end
