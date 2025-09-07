defmodule Tutor.Learning.SessionSupervisorTest do
  use ExUnit.Case, async: true
  
  alias Tutor.Learning.{SessionSupervisor, SessionRegistry}
  
  describe "SessionSupervisor" do
    test "starts a new session successfully" do
      user_id = 1
      session_id = "test-session-#{System.unique_integer()}"
      
      assert {:ok, pid} = SessionSupervisor.start_session(user_id, session_id)
      assert is_pid(pid)
      assert Process.alive?(pid)
      
      # Verify it's registered
      assert {:ok, ^pid} = SessionRegistry.lookup(session_id)
      
      # Clean up
      SessionSupervisor.stop_session(session_id)
    end
    
    test "stops a session successfully" do
      user_id = 1
      session_id = "test-session-#{System.unique_integer()}"
      
      {:ok, pid} = SessionSupervisor.start_session(user_id, session_id)
      assert Process.alive?(pid)
      
      assert :ok = SessionSupervisor.stop_session(session_id)
      
      Process.sleep(100)
      refute Process.alive?(pid)
      assert {:error, :not_found} = SessionRegistry.lookup(session_id)
    end
    
    test "returns error when stopping non-existent session" do
      non_existent_id = "non-existent-#{System.unique_integer()}"
      
      assert {:error, :session_not_found} = SessionSupervisor.stop_session(non_existent_id)
    end
    
    test "lists active sessions" do
      user_id = 1
      session_id1 = "test-session-1-#{System.unique_integer()}"
      session_id2 = "test-session-2-#{System.unique_integer()}"
      
      {:ok, pid1} = SessionSupervisor.start_session(user_id, session_id1)
      {:ok, pid2} = SessionSupervisor.start_session(user_id, session_id2)
      
      active = SessionSupervisor.active_sessions()
      assert pid1 in active
      assert pid2 in active
      
      # Clean up
      SessionSupervisor.stop_session(session_id1)
      SessionSupervisor.stop_session(session_id2)
    end
    
    test "handles concurrent session starts" do
      user_id = 1
      
      tasks = for i <- 1..5 do
        Task.async(fn ->
          session_id = "concurrent-session-#{i}-#{System.unique_integer()}"
          {:ok, pid} = SessionSupervisor.start_session(user_id, session_id)
          {session_id, pid}
        end)
      end
      
      results = Task.await_many(tasks)
      
      # All should have started successfully
      assert length(results) == 5
      
      for {session_id, pid} <- results do
        assert Process.alive?(pid)
        # Clean up
        SessionSupervisor.stop_session(session_id)
      end
    end
    
    test "restarts crashed sessions (restart: :temporary behavior)" do
      user_id = 1
      session_id = "crash-test-#{System.unique_integer()}"
      
      {:ok, pid} = SessionSupervisor.start_session(user_id, session_id)
      
      # Kill the process
      Process.exit(pid, :kill)
      Process.sleep(100)
      
      # With :temporary restart strategy, it should NOT restart
      assert {:error, :not_found} = SessionRegistry.lookup(session_id)
      
      # Active sessions should not include the killed process
      active = SessionSupervisor.active_sessions()
      refute pid in active
    end
  end
end