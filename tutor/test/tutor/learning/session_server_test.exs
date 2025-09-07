defmodule Tutor.Learning.SessionServerTest do
  use ExUnit.Case, async: true
  
  alias Tutor.Learning.{SessionServer, SessionSupervisor}
  
  setup do
    user_id = 1
    session_id = "test-session-#{System.unique_integer()}"
    
    {:ok, _pid} = SessionSupervisor.start_session(user_id, session_id)
    
    on_exit(fn ->
      SessionSupervisor.stop_session(session_id)
    end)
    
    {:ok, session_id: session_id, user_id: user_id}
  end
  
  describe "SessionServer state management" do
    test "initializes with correct default state", %{session_id: session_id} do
      state = SessionServer.get_state(session_id)
      
      assert state.session_id == session_id
      assert state.current_state == :exposition
      assert state.current_topic == nil
      assert state.current_question == nil
      assert state.conversation_history == []
      assert state.session_metrics.questions_attempted == 0
      assert state.session_metrics.correct_answers == 0
    end
    
    test "handles user messages and transitions state", %{session_id: session_id} do
      # First set up a topic so the "ready" message will trigger a question
      SessionServer.start_question_flow(session_id, 1)
      Process.sleep(100)
      
      # Send a "ready" message while in exposition state  
      {:ok, new_state} = SessionServer.handle_user_message(session_id, "I'm ready for a question!")
      
      # Should transition to awaiting_tool_result as it processes the message
      assert new_state == :awaiting_tool_result
    end
    
    test "starts question flow for a topic", %{session_id: session_id} do
      topic_id = 1
      
      {:ok, :generating_question} = SessionServer.start_question_flow(session_id, topic_id)
      
      # Give async task time to complete
      Process.sleep(100)
      
      state = SessionServer.get_state(session_id)
      assert state.current_topic != nil
      assert state.current_topic.id == topic_id
    end
    
    test "tracks conversation history", %{session_id: session_id} do
      # Send multiple messages
      SessionServer.handle_user_message(session_id, "First message")
      Process.sleep(50)
      SessionServer.handle_user_message(session_id, "Second message")
      Process.sleep(50)
      
      state = SessionServer.get_state(session_id)
      
      # Should have recorded the messages in conversation history
      # Note: conversation_history is limited to last 10 in get_state
      assert length(state.conversation_history) > 0
    end
    
    test "gracefully stops session", %{session_id: session_id} do
      assert :ok = SessionServer.stop_session(session_id)
      
      # After stopping, should not be able to interact with it
      Process.sleep(100)
      
      # This should fail as the process is gone
      catch_exit do
        SessionServer.get_state(session_id)
      end
    end
  end
  
  describe "Pedagogical state machine" do
    test "transitions from exposition to awaiting_tool_result", %{session_id: session_id} do
      initial_state = SessionServer.get_state(session_id)
      assert initial_state.current_state == :exposition
      
      # Send a message that triggers tool use
      {:ok, new_state} = SessionServer.handle_user_message(session_id, "Explain addition to me")
      
      assert new_state == :awaiting_tool_result
    end
    
    test "handles ready indicators to start questions", %{session_id: session_id} do
      # Set up a topic first
      SessionServer.start_question_flow(session_id, 1)
      Process.sleep(100)
      
      # Send a "ready" message
      {:ok, _new_state} = SessionServer.handle_user_message(session_id, "I'm ready for a question")
      
      # Should trigger question generation
      Process.sleep(100)
      state = SessionServer.get_state(session_id)
      
      # Should have either generated a question or be in process
      assert state.current_state in [:awaiting_answer, :awaiting_tool_result]
    end
  end
  
  describe "Session metrics" do
    test "initializes metrics correctly", %{session_id: session_id} do
      state = SessionServer.get_state(session_id)
      
      assert state.session_metrics.questions_attempted == 0
      assert state.session_metrics.correct_answers == 0
      assert state.session_metrics.topics_covered == []
      assert state.session_metrics.started_at != nil
    end
    
    test "updates metrics when answering questions", %{session_id: session_id} do
      # Start a question flow
      SessionServer.start_question_flow(session_id, 1)
      Process.sleep(200)
      
      # The mock will generate a question
      state_before = SessionServer.get_state(session_id)
      
      # If a question was generated, try to answer it
      if state_before.current_question != nil do
        SessionServer.handle_user_message(session_id, "4")
        Process.sleep(200)
        
        state_after = SessionServer.get_state(session_id)
        
        # Metrics should be updated after answering
        assert state_after.session_metrics.questions_attempted > state_before.session_metrics.questions_attempted
      end
    end
  end
  
  describe "Error handling" do
    test "handles invalid session_id gracefully" do
      invalid_id = "invalid-session-#{System.unique_integer()}"
      
      # Should exit when trying to call non-existent session
      catch_exit do
        SessionServer.get_state(invalid_id)
      end
    end
    
    test "handles concurrent messages", %{session_id: session_id} do
      # Send multiple messages concurrently
      tasks = for i <- 1..5 do
        Task.async(fn ->
          SessionServer.handle_user_message(session_id, "Message #{i}")
        end)
      end
      
      results = Task.await_many(tasks)
      
      # All should complete without errors
      assert length(results) == 5
      for {status, _} <- results do
        assert status == :ok
      end
    end
  end
end