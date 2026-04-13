# `Workbench.Cmd`

Framework command values resolved by the runtime.

# `t`

```elixir
@type t() :: %Workbench.Cmd{kind: atom(), payload: term()}
```

# `after_ms`

```elixir
@spec after_ms(non_neg_integer(), term()) :: t()
```

# `async`

```elixir
@spec async((-&gt; term()), (term() -&gt; term())) :: t()
```

# `batch`

```elixir
@spec batch([t()]) :: t()
```

# `focus`

```elixir
@spec focus([term()]) :: t()
```

# `message`

```elixir
@spec message(term()) :: t()
```

# `none`

```elixir
@spec none() :: []
```

# `normalize`

```elixir
@spec normalize(term()) :: [t()]
```

# `print`

```elixir
@spec print(String.t()) :: t()
```

# `request`

```elixir
@spec request(term(), keyword(), (term() -&gt; term())) :: t()
```

# `subscribe`

```elixir
@spec subscribe(term(), pos_integer(), term()) :: t()
```

# `unsubscribe`

```elixir
@spec unsubscribe(term()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
