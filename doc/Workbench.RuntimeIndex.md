# `Workbench.RuntimeIndex`

Derived runtime indexes for bindings, actions, and subscriptions.

# `t`

```elixir
@type t() :: %Workbench.RuntimeIndex{
  actions: [Workbench.Action.t()],
  keybindings: [Workbench.Keymap.binding()],
  subscriptions: [Workbench.Subscription.t()]
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
