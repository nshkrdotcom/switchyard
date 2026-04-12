defmodule Workbench.Cmd do
  @moduledoc "Framework command values resolved by the runtime."

  defstruct kind: nil, payload: nil

  @type t :: %__MODULE__{kind: atom(), payload: term()}

  @spec none() :: []
  def none, do: []

  @spec message(term()) :: t()
  def message(message), do: %__MODULE__{kind: :message, payload: message}

  @spec batch([t()]) :: t()
  def batch(commands), do: %__MODULE__{kind: :batch, payload: List.wrap(commands)}

  @spec async((-> term()), (term() -> term())) :: t()
  def async(fun, mapper) when is_function(fun, 0) and is_function(mapper, 1) do
    %__MODULE__{kind: :async, payload: {fun, mapper}}
  end

  @spec after_ms(non_neg_integer(), term()) :: t()
  def after_ms(delay_ms, message) when is_integer(delay_ms) and delay_ms >= 0 do
    %__MODULE__{kind: :after, payload: {delay_ms, message}}
  end

  @spec request(term(), keyword(), (term() -> term())) :: t()
  def request(request, opts \\ [], mapper \\ & &1) when is_function(mapper, 1) do
    %__MODULE__{kind: :request, payload: {request, opts, mapper}}
  end

  @spec subscribe(term(), pos_integer(), term()) :: t()
  def subscribe(id, interval_ms, message) do
    %__MODULE__{kind: :subscribe, payload: {id, interval_ms, message}}
  end

  @spec unsubscribe(term()) :: t()
  def unsubscribe(id), do: %__MODULE__{kind: :unsubscribe, payload: id}

  @spec print(String.t()) :: t()
  def print(line) when is_binary(line), do: %__MODULE__{kind: :print, payload: line}

  @spec focus([term()]) :: t()
  def focus(path) when is_list(path), do: %__MODULE__{kind: :focus, payload: path}

  @spec normalize(term()) :: [t()]
  def normalize(nil), do: []
  def normalize([]), do: []
  def normalize(%__MODULE__{kind: :batch, payload: commands}), do: normalize(commands)
  def normalize(%__MODULE__{} = command), do: [command]
  def normalize(commands) when is_list(commands), do: Enum.flat_map(commands, &normalize/1)
end

defmodule Workbench.Subscription do
  @moduledoc "Framework subscription descriptors."

  defstruct id: nil, kind: :interval, interval_ms: 1_000, message: nil, generation: 0

  @type t :: %__MODULE__{
          id: term(),
          kind: :interval | :once,
          interval_ms: pos_integer(),
          message: term(),
          generation: non_neg_integer()
        }

  @spec interval(term(), pos_integer(), term(), non_neg_integer()) :: t()
  def interval(id, interval_ms, message, generation \\ 0) do
    %__MODULE__{
      id: id,
      kind: :interval,
      interval_ms: interval_ms,
      message: message,
      generation: generation
    }
  end

  @spec once(term(), pos_integer(), term(), non_neg_integer()) :: t()
  def once(id, interval_ms, message, generation \\ 0) do
    %__MODULE__{
      id: id,
      kind: :once,
      interval_ms: interval_ms,
      message: message,
      generation: generation
    }
  end

  @spec to_ex_ratatui(t()) :: ExRatatui.Subscription.t()
  def to_ex_ratatui(%__MODULE__{kind: :interval} = subscription) do
    ExRatatui.Subscription.interval(
      subscription.id,
      subscription.interval_ms,
      subscription.message
    )
  end

  def to_ex_ratatui(%__MODULE__{kind: :once} = subscription) do
    ExRatatui.Subscription.once(subscription.id, subscription.interval_ms, subscription.message)
  end
end

defmodule Workbench.EffectRunner do
  @moduledoc "Maps framework commands to ExRatatui runtime commands."

  alias ExRatatui.Command
  alias Workbench.Cmd
  alias Workbench.Context

  @spec run(term(), Context.t()) :: [Command.t()]
  def run(commands, %Context{} = ctx) do
    commands
    |> Cmd.normalize()
    |> Enum.flat_map(&resolve(&1, ctx))
  end

  defp resolve(%Cmd{kind: :message, payload: message}, _ctx), do: [Command.message(message)]

  defp resolve(%Cmd{kind: :after, payload: {delay_ms, message}}, _ctx),
    do: [Command.send_after(delay_ms, message)]

  defp resolve(%Cmd{kind: :async, payload: {fun, mapper}}, _ctx) do
    [Command.async(fun, mapper)]
  end

  defp resolve(%Cmd{kind: :request, payload: {request, opts, mapper}}, %Context{} = ctx) do
    request_handler =
      ctx.request_handler || fn _request, _opts -> {:error, :missing_request_handler} end

    [
      Command.async(
        fn -> request_handler.(request, opts) end,
        mapper
      )
    ]
  end

  defp resolve(%Cmd{kind: :print, payload: line}, _ctx),
    do: [Command.message({:workbench_print, line})]

  defp resolve(%Cmd{kind: :focus, payload: path}, _ctx),
    do: [Command.message({:workbench_focus, path})]

  defp resolve(%Cmd{kind: :subscribe}, _ctx), do: []
  defp resolve(%Cmd{kind: :unsubscribe}, _ctx), do: []
end
