defmodule Tutor.Learning.SessionSupervisor do
  @moduledoc """
  DynamicSupervisor for managing SessionServer processes.
  
  Each active tutoring session gets its own SessionServer process.
  This supervisor handles starting, stopping, and restarting sessions.
  """
  
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new SessionServer for the given user_id and session_id.
  """
  def start_session(user_id, session_id, opts \\ []) do
    child_spec = {Tutor.Learning.SessionServer, [user_id: user_id, session_id: session_id] ++ opts}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Stops a SessionServer for the given session_id.
  """
  def stop_session(session_id) do
    case Tutor.Learning.SessionRegistry.lookup(session_id) do
      {:ok, pid} ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
      {:error, :not_found} ->
        {:error, :session_not_found}
    end
  end

  @doc """
  Returns a list of all active session PIDs.
  """
  def active_sessions do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.filter(fn {_, pid, _, _} -> is_pid(pid) end)
    |> Enum.map(fn {_, pid, _, _} -> pid end)
  end
end