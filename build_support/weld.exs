unless Code.ensure_loaded?(Switchyard.Build.WeldContract) do
  Code.require_file("weld_contract.exs", __DIR__)
end

Switchyard.Build.WeldContract.manifest()
