# `Workbench.Layout`

Declarative layout intent for a node subtree.

# `constraint`

```elixir
@type constraint() ::
  {:percentage, non_neg_integer()}
  | {:length, non_neg_integer()}
  | {:min, non_neg_integer()}
  | {:max, non_neg_integer()}
  | {:ratio, non_neg_integer(), non_neg_integer()}
```

# `direction`

```elixir
@type direction() :: :vertical | :horizontal | nil
```

# `padding`

```elixir
@type padding() ::
  {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
```

# `t`

```elixir
@type t() :: %Workbench.Layout{
  constraints: [constraint()],
  direction: direction(),
  padding: padding()
}
```

# `normalize_padding`

```elixir
@spec normalize_padding(padding() | [non_neg_integer()] | non_neg_integer() | nil) ::
  padding()
```

# `with_padding`

```elixir
@spec with_padding(t(), padding() | [non_neg_integer()] | non_neg_integer()) :: t()
@spec with_padding(
  Workbench.Node.t(),
  padding() | [non_neg_integer()] | non_neg_integer()
) ::
  Workbench.Node.t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
