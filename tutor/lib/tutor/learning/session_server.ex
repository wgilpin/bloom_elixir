defmodule Tutor.Learning.SessionServer do
  @moduledoc """
  GenServer that manages individual tutoring sessions with pedagogical state machine.
  
  State transitions:
  - :exposition -> :awaiting_answer (after presenting question/concept)
  - :awaiting_answer -> :awaiting_tool_result (when processing student response)
  - :awaiting_tool_result -> :exposition | :remediating (based on tool result)
  - :remediating -> :exposition (after providing intervention)
  
  Each session maintains user context, current topic, question history, and progress.
  """
  
  use GenServer, restart: :temporary

  alias Tutor.Learning.{SessionRegistry, ToolTaskSupervisor, SessionPersistence}
  alias Tutor.{Repo, Accounts, Curriculum}

  defstruct [
    :user_id,
    :session_id,
    :current_state,
    :user,
    :current_topic,
    :current_question,
    :conversation_history,
    :active_tasks,
    :session_metrics,
    :last_activity
  ]

  # Client API

  def start_link(opts) do
    user_id = Keyword.fetch!(opts, :user_id)
    session_id = Keyword.fetch!(opts, :session_id)
    
    GenServer.start_link(__MODULE__, opts, name: via_tuple(session_id))
  end

  @doc """
  Sends a user message to the session for processing.
  """
  def handle_user_message(session_id, message) do
    GenServer.call(via_tuple(session_id), {:user_message, message})
  end

  @doc """
  Gets the current session state.
  """
  def get_state(session_id) do
    GenServer.call(via_tuple(session_id), :get_state)
  end

  @doc """
  Starts a new question flow for the given topic.
  """
  def start_question_flow(session_id, topic_id) do
    GenServer.call(via_tuple(session_id), {:start_question_flow, topic_id})
  end

  @doc """
  Gracefully shuts down the session, persisting state.
  """
  def stop_session(session_id) do
    GenServer.call(via_tuple(session_id), :stop_session)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    user_id = Keyword.fetch!(opts, :user_id)
    session_id = Keyword.fetch!(opts, :session_id)
    
    # Load user data (mock for now since Accounts context doesn't exist yet)
    user = %{id: user_id, name: "Test User"}
    
    state = %__MODULE__{
      user_id: user_id,
      session_id: session_id,
      current_state: :exposition,
      user: user,
      current_topic: nil,
      current_question: nil,
      conversation_history: [],
      active_tasks: %{},
      session_metrics: %{
        started_at: DateTime.utc_now(),
        questions_attempted: 0,
        correct_answers: 0,
        topics_covered: []
      },
      last_activity: DateTime.utc_now()
    }
    
    # Schedule periodic persistence
    Process.send_after(self(), :persist_session, 30_000)
    
    {:ok, state}
  end

  @impl true
  def handle_call({:user_message, message}, _from, state) do
    new_state = process_user_message(state, message)
    {:reply, {:ok, new_state.current_state}, new_state}
  end

  def handle_call(:get_state, _from, state) do
    public_state = %{
      session_id: state.session_id,
      current_state: state.current_state,
      current_topic: state.current_topic,
      current_question: state.current_question,
      conversation_history: Enum.take(state.conversation_history, -10),  # Last 10 messages
      session_metrics: state.session_metrics
    }
    {:reply, public_state, state}
  end

  def handle_call({:start_question_flow, topic_id}, _from, state) do
    # Mock topic for now since Curriculum context doesn't exist yet
    topic = %{id: topic_id, name: "Mock Topic #{topic_id}"}
    
    new_state = %{state | 
      current_topic: topic,
      current_state: :exposition
    }
    # Start async question generation
    generate_question_async(new_state)
    {:reply, {:ok, :generating_question}, new_state}
  end

  def handle_call(:stop_session, _from, state) do
    # Mock persistence for now until database is fully set up
    # SessionPersistence.end_session(state)
    {:stop, :normal, :ok, state}
  end

  @impl true
  def handle_info({:tool_result, task_pid, result}, state) do
    case Map.get(state.active_tasks, task_pid) do
      nil ->
        # Task not found in active tasks, ignore
        {:noreply, state}
      
      task_type ->
        new_state = process_tool_result(state, task_type, result, task_pid)
        {:noreply, new_state}
    end
  end
  
  # Handle Task.async results
  def handle_info({ref, result}, state) when is_reference(ref) do
    # This is a Task.async result
    case Map.get(state.active_tasks, ref) do
      nil ->
        # Unknown task, ignore
        Process.demonitor(ref, [:flush])
        {:noreply, state}
      
      {_task, task_type} ->
        # Process the result
        active_tasks = Map.delete(state.active_tasks, ref)
        state = %{state | active_tasks: active_tasks}
        new_state = process_tool_result(state, task_type, {:ok, result}, ref)
        Process.demonitor(ref, [:flush])
        {:noreply, new_state}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Clean up dead task references
    active_tasks = Map.delete(state.active_tasks, pid)
    {:noreply, %{state | active_tasks: active_tasks}}
  end

  def handle_info(:persist_session, state) do
    # Mock persistence for now until database is fully set up
    # SessionPersistence.persist_session(state)
    # Schedule next persistence
    Process.send_after(self(), :persist_session, 30_000)  # Every 30 seconds
    {:noreply, state}
  end

  # Private Functions

  defp via_tuple(session_id) do
    {:via, Registry, {SessionRegistry, session_id}}
  end

  defp process_user_message(state, message) do
    state = add_to_conversation(state, :user, message)
    
    case state.current_state do
      :exposition ->
        # User asking questions or ready for challenge
        handle_exposition_message(state, message)
      
      :awaiting_answer ->
        # User providing answer to current question
        handle_answer_message(state, message)
      
      :awaiting_tool_result ->
        # Still processing, acknowledge but don't change state
        add_to_conversation(state, :system, "Processing your response...")
      
      :remediating ->
        # User responding to remediation
        handle_remediation_message(state, message)
    end
  end

  defp handle_exposition_message(state, message) do
    cond do
      contains_ready_indicators?(message) ->
        if state.current_topic do
          generate_question_async(state)
          %{state | current_state: :awaiting_tool_result}
        else
          add_to_conversation(state, :system, "Please select a topic first.")
        end
      
      true ->
        # General conversation or explanation request
        explain_concept_async(state, message)
        %{state | current_state: :awaiting_tool_result}
    end
  end

  defp handle_answer_message(state, answer) do
    if state.current_question do
      check_answer_async(state, answer)
      %{state | current_state: :awaiting_tool_result}
    else
      add_to_conversation(state, :system, "No active question to answer.")
    end
  end

  defp handle_remediation_message(state, message) do
    # After remediation, typically move back to exposition or generate new question
    cond do
      contains_ready_indicators?(message) ->
        generate_question_async(state)
        %{state | current_state: :awaiting_tool_result}
      
      true ->
        # Continue conversation
        %{state | current_state: :exposition}
    end
  end

  defp process_tool_result(state, task_type, result, task_pid) do
    active_tasks = Map.delete(state.active_tasks, task_pid)
    state = %{state | active_tasks: active_tasks}
    
    case {task_type, result} do
      {:generate_question, {:ok, question_data}} ->
        %{state |
          current_question: question_data,
          current_state: :awaiting_answer
        }
        |> add_to_conversation(:system, question_data["text"])
      
      {:check_answer, {:ok, check_result}} ->
        handle_answer_check_result(state, check_result)
      
      {:explain_concept, {:ok, explanation}} ->
        %{state | current_state: :exposition}
        |> add_to_conversation(:system, explanation)
      
      {:diagnose_error, {:ok, diagnosis}} ->
        create_remediation_async(state, diagnosis)
        state
      
      {:create_remediation, {:ok, remediation}} ->
        %{state | current_state: :remediating}
        |> add_to_conversation(:system, remediation)
      
      {_, {:error, error}} ->
        add_to_conversation(state, :system, "I encountered an error. Let me try again.")
    end
  end

  defp handle_answer_check_result(state, check_result) do
    is_correct = check_result["is_correct"]
    
    state = update_session_metrics(state, is_correct)
    
    if is_correct do
      %{state | 
        current_state: :exposition,
        current_question: nil
      }
      |> add_to_conversation(:system, check_result["feedback"])
    else
      # Diagnose the error for remediation
      diagnose_error_async(state, check_result)
      %{state | current_state: :awaiting_tool_result}
    end
  end

  # Tool execution functions
  
  defp generate_question_async(state) do
    task = ToolTaskSupervisor.async_tool_call(
      Tutor.Tools, 
      :generate_question, 
      [state.current_topic]
    )
    monitor_task(state, task, :generate_question)
  end

  defp check_answer_async(state, answer) do
    task = ToolTaskSupervisor.async_tool_call(
      Tutor.Tools,
      :check_answer,
      [state.current_question, answer]
    )
    monitor_task(state, task, :check_answer)
  end

  defp explain_concept_async(state, message) do
    task = ToolTaskSupervisor.async_tool_call(
      Tutor.Tools,
      :explain_concept,
      [state.current_topic, message]
    )
    monitor_task(state, task, :explain_concept)
  end

  defp diagnose_error_async(state, check_result) do
    task = ToolTaskSupervisor.async_tool_call(
      Tutor.Tools,
      :diagnose_error,
      [state.current_question, check_result]
    )
    monitor_task(state, task, :diagnose_error)
  end

  defp create_remediation_async(state, diagnosis) do
    task = ToolTaskSupervisor.async_tool_call(
      Tutor.Tools,
      :create_remediation,
      [state.current_topic, diagnosis]
    )
    monitor_task(state, task, :create_remediation)
  end

  defp monitor_task(state, task, task_type) do
    # Store both the task struct and type for proper handling
    active_tasks = Map.put(state.active_tasks, task.ref, {task, task_type})
    %{state | active_tasks: active_tasks}
  end

  # Helper functions

  defp add_to_conversation(state, role, content) do
    entry = %{
      role: role,
      content: content,
      timestamp: DateTime.utc_now()
    }
    
    conversation_history = [entry | state.conversation_history]
    %{state | 
      conversation_history: conversation_history,
      last_activity: DateTime.utc_now()
    }
  end

  defp contains_ready_indicators?(message) do
    message = String.downcase(message)
    Enum.any?(["ready", "next", "question", "challenge", "test"], fn indicator ->
      String.contains?(message, indicator)
    end)
  end

  defp update_session_metrics(state, is_correct) do
    metrics = state.session_metrics
    new_metrics = %{metrics |
      questions_attempted: metrics.questions_attempted + 1,
      correct_answers: if(is_correct, do: metrics.correct_answers + 1, else: metrics.correct_answers)
    }
    %{state | session_metrics: new_metrics}
  end

end