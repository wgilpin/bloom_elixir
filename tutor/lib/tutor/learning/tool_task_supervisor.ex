defmodule Tutor.Learning.ToolTaskSupervisor do
  @moduledoc """
  Task.Supervisor for managing async LLM tool execution.
  
  Prevents SessionServer processes from blocking on external API calls.
  Each tool call (check_answer, generate_question, etc.) runs as a supervised task.
  """

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: :infinity
    }
  end

  def start_link(_init_arg) do
    Task.Supervisor.start_link(name: __MODULE__)
  end

  @doc """
  Executes a tool function asynchronously and monitors the result.
  
  Returns a Task struct that the calling process can monitor.
  """
  def async_tool_call(module, function, args) do
    Task.Supervisor.async(__MODULE__, module, function, args)
  end

  @doc """
  Executes a tool function asynchronously without monitoring.
  
  Use when fire-and-forget behavior is desired.
  """
  def async_tool_call_nolink(module, function, args) do
    Task.Supervisor.async_nolink(__MODULE__, module, function, args)
  end

  @doc """
  Starts a linked task for tool execution with timeout.
  """
  def start_tool_task(session_pid, tool_function, args, _timeout \\ 30_000) do
    Task.Supervisor.start_child(__MODULE__, fn ->
      try do
        result = apply(tool_function, args)
        send(session_pid, {:tool_result, self(), {:ok, result}})
      rescue
        error ->
          send(session_pid, {:tool_result, self(), {:error, error}})
      end
    end)
  end
end