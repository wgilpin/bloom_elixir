defmodule Tutor.Learning.SessionRegistryTest do
  use ExUnit.Case, async: true
  
  alias Tutor.Learning.SessionRegistry
  
  describe "SessionRegistry" do
    test "registers and looks up a session" do
      session_id = "test-session-#{System.unique_integer()}"
      
      # Register the current process with a session_id
      assert {:ok, _} = SessionRegistry.register(session_id)
      
      # Should be able to look it up
      assert {:ok, pid} = SessionRegistry.lookup(session_id)
      assert pid == self()
    end
    
    test "returns error when session not found" do
      non_existent_id = "non-existent-#{System.unique_integer()}"
      
      assert {:error, :not_found} = SessionRegistry.lookup(non_existent_id)
    end
    
    test "lists all registered session_ids" do
      session_id1 = "test-session-1-#{System.unique_integer()}"
      session_id2 = "test-session-2-#{System.unique_integer()}"
      
      {:ok, _} = SessionRegistry.register(session_id1)
      
      # Start another process and register it
      task = Task.async(fn ->
        {:ok, _} = SessionRegistry.register(session_id2)
        Process.sleep(100)
      end)
      
      Process.sleep(50)
      
      all_ids = SessionRegistry.all_session_ids()
      assert session_id1 in all_ids
      assert session_id2 in all_ids
      
      Task.await(task)
    end
    
    test "returns session_id for a given PID" do
      session_id = "test-session-#{System.unique_integer()}"
      
      {:ok, _} = SessionRegistry.register(session_id)
      
      assert SessionRegistry.session_id_for_pid(self()) == session_id
    end
    
    test "handles duplicate registration attempts" do
      session_id = "test-session-#{System.unique_integer()}"
      
      # First registration should succeed
      assert {:ok, _} = SessionRegistry.register(session_id)
      
      # Second registration with same ID should fail
      assert {:error, {:already_registered, _}} = SessionRegistry.register(session_id)
    end
  end
end