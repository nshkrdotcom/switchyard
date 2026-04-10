defmodule Switchyard.JobRuntimeTest do
  use ExUnit.Case, async: true

  alias Switchyard.JobRuntime

  test "creates queued jobs with progress and timestamps" do
    job = JobRuntime.new(%{id: "job-1", kind: :process_start, title: "Start process"})

    assert job.status == :queued
    assert job.progress == %{current: 0, total: 0}
    assert %DateTime{} = job.started_at
  end

  test "supports valid transitions and terminal timestamps" do
    job = JobRuntime.new(%{id: "job-1", kind: :process_start, title: "Start process"})
    {:ok, running} = JobRuntime.transition(job, :running)
    {:ok, done} = JobRuntime.transition(running, :succeeded)

    assert running.status == :running
    assert done.status == :succeeded
    assert %DateTime{} = done.finished_at
  end

  test "rejects invalid transitions" do
    job = JobRuntime.new(%{id: "job-1", kind: :process_start, title: "Start process"})
    {:ok, running} = JobRuntime.transition(job, :running)

    assert {:error, :invalid_transition} = JobRuntime.transition(running, :queued)
  end

  test "updates progress" do
    job = JobRuntime.new(%{id: "job-1", kind: :process_start, title: "Start process"})

    assert %{progress: %{current: 1, total: 3}} = JobRuntime.update_progress(job, 1, 3)
  end
end
