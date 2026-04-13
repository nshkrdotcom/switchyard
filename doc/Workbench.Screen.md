# `Workbench.Screen`

Runtime screen configuration and viewport metadata.

# `mode`

```elixir
@type mode() :: :inline | :fullscreen | :mixed | :accessible
```

# `t`

```elixir
@type t() :: %Workbench.Screen{
  height: non_neg_integer(),
  mode: mode(),
  width: non_neg_integer()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
