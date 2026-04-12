defmodule Workbench.Component do
  @moduledoc "Component behaviour for framework-backed screens and widgets."

  @type callback_opts ::
          Workbench.Cmd.t()
          | [Workbench.Cmd.t()]
          | keyword()
          | map()

  @callback init(props :: map(), ctx :: Workbench.Context.t()) ::
              {:ok, state :: term(), opts :: callback_opts()}

  @callback update(
              msg :: term(),
              state :: term(),
              props :: map(),
              ctx :: Workbench.Context.t()
            ) ::
              {:ok, state :: term(), opts :: callback_opts()}
              | {:stop, state :: term()}
              | {:stop, state :: term(), opts :: callback_opts()}
              | :unhandled

  @callback render(state :: term(), props :: map(), ctx :: Workbench.Context.t()) ::
              Workbench.Node.t()

  @callback render_accessible(state :: term(), props :: map(), ctx :: Workbench.Context.t()) ::
              Workbench.Accessibility.Node.t()
              | [Workbench.Accessibility.Node.t()]
              | :unsupported

  @callback handle_info(
              msg :: term(),
              state :: term(),
              props :: map(),
              ctx :: Workbench.Context.t()
            ) ::
              {:ok, state :: term(), opts :: callback_opts()}
              | {:stop, state :: term()}
              | {:stop, state :: term(), opts :: callback_opts()}
              | :unhandled

  @callback keymap(state :: term(), props :: map(), ctx :: Workbench.Context.t()) ::
              [Workbench.Keymap.binding()]

  @callback actions(state :: term(), props :: map(), ctx :: Workbench.Context.t()) ::
              [Workbench.Action.t()]

  @callback subscriptions(state :: term(), props :: map(), ctx :: Workbench.Context.t()) ::
              [Workbench.Subscription.t()]

  @callback mode() :: :pure | :supervised

  @optional_callbacks [
    render_accessible: 3,
    handle_info: 4,
    keymap: 3,
    actions: 3,
    subscriptions: 3,
    mode: 0
  ]

  @spec mode(module()) :: :pure | :supervised
  def mode(module) do
    if function_exported?(module, :mode, 0), do: module.mode(), else: :pure
  end
end

defmodule Workbench.ComponentServer do
  @moduledoc "GenServer wrapper for supervised framework components."

  use GenServer

  defstruct module: nil, props: %{}, ctx: nil, state: nil

  @type t :: %__MODULE__{
          module: module(),
          props: map(),
          ctx: Workbench.Context.t(),
          state: term()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, Keyword.take(opts, [:name]))
  end

  @spec update(pid(), term(), Workbench.Context.t()) :: :ok
  def update(pid, msg, %Workbench.Context{} = ctx) do
    GenServer.cast(pid, {:update, msg, ctx})
  end

  @spec snapshot(pid()) :: t()
  def snapshot(pid), do: GenServer.call(pid, :snapshot)

  @impl true
  def init(opts) do
    module = Keyword.fetch!(opts, :module)
    props = Keyword.get(opts, :props, %{})
    ctx = Keyword.fetch!(opts, :ctx)
    {:ok, state, _cmds} = module.init(props, ctx)
    {:ok, %__MODULE__{module: module, props: props, ctx: ctx, state: state}}
  end

  @impl true
  def handle_cast({:update, msg, ctx}, %__MODULE__{} = server) do
    case server.module.update(msg, server.state, server.props, ctx) do
      {:ok, state, _cmds} -> {:noreply, %{server | state: state, ctx: ctx}}
      {:stop, state} -> {:stop, :normal, %{server | state: state, ctx: ctx}}
      {:stop, state, _cmds} -> {:stop, :normal, %{server | state: state, ctx: ctx}}
      :unhandled -> {:noreply, %{server | ctx: ctx}}
    end
  end

  @impl true
  def handle_call(:snapshot, _from, %__MODULE__{} = server), do: {:reply, server, server}

  @impl true
  def handle_info(msg, %__MODULE__{} = server) do
    if function_exported?(server.module, :handle_info, 4) do
      case server.module.handle_info(msg, server.state, server.props, server.ctx) do
        {:ok, state, _cmds} -> {:noreply, %{server | state: state}}
        {:stop, state} -> {:stop, :normal, %{server | state: state}}
        {:stop, state, _cmds} -> {:stop, :normal, %{server | state: state}}
        :unhandled -> {:noreply, server}
      end
    else
      {:noreply, server}
    end
  end
end

defmodule Workbench.ComponentSupervisor do
  @moduledoc "Dynamic supervisor for supervised component processes."

  use DynamicSupervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok), do: DynamicSupervisor.init(strategy: :one_for_one)

  @spec start_component(pid(), keyword()) :: DynamicSupervisor.on_start_child()
  def start_component(supervisor, opts) do
    spec = {Workbench.ComponentServer, opts}
    DynamicSupervisor.start_child(supervisor, spec)
  end
end
