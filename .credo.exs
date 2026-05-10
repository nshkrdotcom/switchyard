%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "mix.exs",
          "apps/*/lib/",
          "core/*/lib/",
          "sites/*/lib/",
          "examples/"
        ],
        excluded: [
          "_build/",
          "deps/",
          "dist/"
        ]
      },
      checks: [
        {Weld.Credo.Check.NoRuntimeOsEnv, []},
        {Credo.Check.Design.AliasUsage, false},
        {Credo.Check.Refactor.CyclomaticComplexity, false}
      ]
    }
  ]
}
