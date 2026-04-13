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

  alias Workbench.Cmd

  @type runtime_opts :: %{
          commands: [Cmd.t()],
          render?: boolean(),
          trace?: term()
        }

  defstruct module: nil,
            props: %{},
            ctx: nil,
            state: nil,
            runtime_opts: %{commands: [], render?: true, trace?: nil}

  @type t :: %__MODULE__{
          module: module(),
          props: map(),
          ctx: Workbench.Context.t(),
          state: term(),
          runtime_opts: runtime_opts()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, Keyword.take(opts, [:name]))
  end

  @spec update(pid(), term(), Workbench.Context.t()) ::
          {:ok, t(), runtime_opts()}
          | {:stop, t()}
          | {:stop, t(), runtime_opts()}
          | :unhandled
  def update(pid, msg, %Workbench.Context{} = ctx) do
    GenServer.call(pid, {:update, msg, ctx})
  end

  @spec snapshot(pid()) :: t()
  def snapshot(pid), do: GenServer.call(pid, :snapshot)

  @impl true
  def init(opts) do
    module = Keyword.fetch!(opts, :module)
    props = Keyword.get(opts, :props, %{})
    ctx = Keyword.fetch!(opts, :ctx)
    {:ok, state, runtime_opts} = module.init(props, ctx)

    {:ok,
     %__MODULE__{
       module: module,
       props: props,
       ctx: ctx,
       state: state,
       runtime_opts: normalize_runtime_opts(runtime_opts)
     }}
  end

  @impl true
  def handle_call({:update, msg, ctx}, _from, %__MODULE__{} = server) do
    case server.module.update(msg, server.state, server.props, ctx) do
      {:ok, state, runtime_opts} ->
        next_server = %{
          server
          | state: state,
            ctx: ctx,
            runtime_opts: normalize_runtime_opts(runtime_opts)
        }

        {:reply, {:ok, next_server, next_server.runtime_opts}, next_server}

      {:stop, state} ->
        next_server = %{server | state: state, ctx: ctx, runtime_opts: default_runtime_opts()}
        {:stop, :normal, {:stop, next_server}, next_server}

      {:stop, state, runtime_opts} ->
        next_server = %{
          server
          | state: state,
            ctx: ctx,
            runtime_opts: normalize_runtime_opts(runtime_opts)
        }

        {:stop, :normal, {:stop, next_server, next_server.runtime_opts}, next_server}

      :unhandled ->
        {:reply, :unhandled, %{server | ctx: ctx}}
    end
  end

  @impl true
  def handle_call(:snapshot, _from, %__MODULE__{} = server), do: {:reply, server, server}

  @impl true
  def handle_info(msg, %__MODULE__{} = server) do
    if function_exported?(server.module, :handle_info, 4) do
      case server.module.handle_info(msg, server.state, server.props, server.ctx) do
        {:ok, state, runtime_opts} ->
          {:noreply, %{server | state: state, runtime_opts: normalize_runtime_opts(runtime_opts)}}

        {:stop, state} ->
          {:stop, :normal, %{server | state: state, runtime_opts: default_runtime_opts()}}

        {:stop, state, runtime_opts} ->
          {:stop, :normal,
           %{server | state: state, runtime_opts: normalize_runtime_opts(runtime_opts)}}

        :unhandled ->
          {:noreply, server}
      end
    else
      {:noreply, server}
    end
  end

  defp default_runtime_opts do
    %{commands: [], render?: true, trace?: nil}
  end

  defp normalize_runtime_opts(nil), do: default_runtime_opts()

  defp normalize_runtime_opts(%Cmd{} = command) do
    %{default_runtime_opts() | commands: Cmd.normalize(command)}
  end

  defp normalize_runtime_opts(runtime_opts) when is_list(runtime_opts) do
    if Keyword.keyword?(runtime_opts) and
         Enum.any?(runtime_opts, fn {key, _value} -> key in [:commands, :render?, :trace?] end) do
      %{
        commands: runtime_opts |> Keyword.get(:commands, []) |> Cmd.normalize(),
        render?: Keyword.get(runtime_opts, :render?, true),
        trace?: Keyword.get(runtime_opts, :trace?)
      }
    else
      %{default_runtime_opts() | commands: Cmd.normalize(runtime_opts)}
    end
  end

  defp normalize_runtime_opts(%{} = runtime_opts) do
    %{
      commands:
        runtime_opts
        |> Map.get(:commands, Map.get(runtime_opts, "commands", []))
        |> Cmd.normalize(),
      render?: Map.get(runtime_opts, :render?, Map.get(runtime_opts, "render?", true)),
      trace?: Map.get(runtime_opts, :trace?, Map.get(runtime_opts, "trace?"))
    }
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
