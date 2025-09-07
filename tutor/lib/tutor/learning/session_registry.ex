defmodule Tutor.Learning.SessionRegistry do
  @moduledoc """
  Registry for tracking SessionServer processes by session_id.
  
  Provides process discovery for active tutoring sessions.
  """

  def child_spec(_) do
    Registry.child_spec(keys: :unique, name: __MODULE__)
  end

  @doc """
  Registers the current process with the given session_id.
  """
  def register(session_id) do
    Registry.register(__MODULE__, session_id, nil)
  end

  @doc """
  Looks up the PID for a given session_id.
  """
  def lookup(session_id) do
    case Registry.lookup(__MODULE__, session_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Returns all registered session_ids.
  """
  def all_session_ids do
    Registry.select(__MODULE__, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  @doc """
  Returns the session_id for the given PID, if registered.
  """
  def session_id_for_pid(pid) do
    Registry.keys(__MODULE__, pid)
    |> List.first()
  end
end