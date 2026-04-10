defmodule Switchyard.JobRuntime do
  @moduledoc """
  Job contract helpers and state transitions.
  """

  alias Switchyard.Contracts.Job

  @terminal_statuses [:succeeded, :failed, :cancelled, :timed_out]

  @spec new(map()) :: Job.t()
  def new(attrs) when is_map(attrs) do
    attrs
    |> Map.put_new(:status, :queued)
    |> Map.put_new(:progress, %{current: 0, total: 0})
    |> Map.put_new(:started_at, DateTime.utc_now())
    |> Job.new!()
  end

  @spec transition(Job.t(), atom()) :: {:ok, Job.t()} | {:error, :invalid_transition}
  def transition(%Job{} = job, new_status)
      when new_status in [:queued, :running | @terminal_statuses] do
    if valid_transition?(job.status, new_status) do
      {:ok, apply_transition(job, new_status)}
    else
      {:error, :invalid_transition}
    end
  end

  @spec update_progress(Job.t(), non_neg_integer(), non_neg_integer()) :: Job.t()
  def update_progress(%Job{} = job, current, total)
      when is_integer(current) and current >= 0 and is_integer(total) and total >= 0 do
    %{job | progress: %{current: current, total: total}}
  end

  defp valid_transition?(:queued, :running), do: true
  defp valid_transition?(:queued, status) when status in @terminal_statuses, do: true
  defp valid_transition?(:running, status) when status in @terminal_statuses, do: true
  defp valid_transition?(status, status), do: true
  defp valid_transition?(_current, _next), do: false

  defp apply_transition(job, new_status) when new_status in @terminal_statuses do
    %{job | status: new_status, finished_at: DateTime.utc_now()}
  end

  defp apply_transition(job, new_status), do: %{job | status: new_status}
end
