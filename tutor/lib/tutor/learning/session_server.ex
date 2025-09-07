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
  alias TutorEx.Learning.PedagogicalStateMachine, as: PSM
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
      current_state: PSM.initial_state(),
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
    
    # Trigger initialization
    send(self(), :initialize_session)
    
    # Schedule periodic persistence
    Process.send_after(self(), :persist_session, 30_000)
    
    {:ok, state}
  end

  @impl true
  def handle_call({:user_message, message}, _from, state) do
    if PSM.accepts_user_input?(state.current_state) do
      new_state = process_user_message(state, message)
      {:reply, {:ok, new_state.current_state}, new_state}
    else
      {:reply, {:error, :state_does_not_accept_input}, state}
    end
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
    
    # Transition to exposition state for new topic
    case PSM.transition(state.current_state, :next_topic) do
      {:ok, new_pedagogical_state} ->
        new_state = %{state | 
          current_topic: topic,
          current_state: new_pedagogical_state
        }
        # Trigger state entry action
        new_state = handle_state_entry(new_state, new_pedagogical_state)
        {:reply, {:ok, :topic_started}, new_state}
      
      {:error, :invalid_transition} ->
        # Force transition if we're in an incompatible state
        new_state = %{state | 
          current_topic: topic,
          current_state: :exposition
        }
        new_state = handle_state_entry(new_state, :exposition)
        {:reply, {:ok, :topic_started}, new_state}
    end
  end

  def handle_call(:stop_session, _from, state) do
    # Mock persistence for now until database is fully set up
    # SessionPersistence.end_session(state)
    {:stop, :normal, :ok, state}
  end

  @impl true
  def handle_info(:initialize_session, state) do
    # Transition from initializing to exposition
    case PSM.transition(state.current_state, :initialized) do
      {:ok, new_pedagogical_state} ->
        new_state = %{state | current_state: new_pedagogical_state}
        new_state = handle_state_entry(new_state, new_pedagogical_state)
        {:noreply, new_state}
      
      _ ->
        {:noreply, state}
    end
  end
  
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
      
      :evaluating_answer ->
        # Still processing, acknowledge but don't change state
        add_to_conversation(state, :system, "Processing your response...")
      
      :guiding_student ->
        # User in guided dialogue
        handle_guiding_message(state, message)
        
      state when state in [:remediating_known_error, :remediating_unknown_error] ->
        # User responding to remediation
        handle_remediation_message(state, message)
        
      _ ->
        state
    end
  end

  defp handle_exposition_message(state, message) do
    cond do
      contains_ready_indicators?(message) ->
        if state.current_topic do
          # Transition to setting_question
          case PSM.transition(state.current_state, :instruction_complete) do
            {:ok, new_pedagogical_state} ->
              new_state = %{state | current_state: new_pedagogical_state}
              handle_state_entry(new_state, new_pedagogical_state)
            _ ->
              add_to_conversation(state, :system, "I'm still preparing the content.")
          end
        else
          add_to_conversation(state, :system, "Please select a topic first.")
        end
      
      true ->
        # General conversation or explanation request
        explain_concept_async(state, message)
        state
    end
  end

  defp handle_answer_message(state, answer) do
    if state.current_question do
      # Transition to evaluating_answer
      case PSM.transition(state.current_state, :answer_received) do
        {:ok, new_pedagogical_state} ->
          new_state = %{state | current_state: new_pedagogical_state}
          check_answer_async(new_state, answer)
        _ ->
          add_to_conversation(state, :system, "Please wait, I'm still processing.")
      end
    else
      add_to_conversation(state, :system, "No active question to answer.")
    end
  end

  defp handle_remediation_message(state, message) do
    # After remediation, transition back to awaiting_answer
    cond do
      contains_ready_indicators?(message) ->
        case PSM.transition(state.current_state, :retry_question) do
          {:ok, new_pedagogical_state} ->
            %{state | current_state: new_pedagogical_state}
            |> add_to_conversation(:system, "Let's try the question again: #{state.current_question["text"]}")
          _ ->
            state
        end
      
      true ->
        # Continue remediation dialogue
        state
    end
  end
  
  defp handle_guiding_message(state, message) do
    # Handle dialogue during guided student support
    cond do
      contains_understanding_indicators?(message) ->
        # Student indicates understanding, retry question
        case PSM.transition(state.current_state, :retry_question) do
          {:ok, new_pedagogical_state} ->
            %{state | current_state: new_pedagogical_state}
            |> add_to_conversation(:system, "Great! Let's try the question again: #{state.current_question["text"]}")
          _ ->
            state
        end
      
      true ->
        # Continue guided dialogue
        provide_guided_hint_async(state, message)
        state
    end
  end

  defp process_tool_result(state, task_type, result, task_pid) do
    active_tasks = Map.delete(state.active_tasks, task_pid)
    state = %{state | active_tasks: active_tasks}
    
    case {task_type, result} do
      {:generate_question, {:ok, question_data}} ->
        # Transition from setting_question to awaiting_answer
        case PSM.transition(state.current_state, :question_presented) do
          {:ok, new_pedagogical_state} ->
            %{state |
              current_question: question_data,
              current_state: new_pedagogical_state
            }
            |> add_to_conversation(:system, question_data["text"])
          _ ->
            state
        end
      
      {:check_answer, {:ok, check_result}} ->
        handle_answer_check_result(state, check_result)
      
      {:explain_concept, {:ok, explanation}} ->
        add_to_conversation(state, :system, explanation)
      
      {:diagnose_error, {:ok, diagnosis}} ->
        handle_error_diagnosis(state, diagnosis)
      
      {:create_remediation, {:ok, remediation}} ->
        add_to_conversation(state, :system, remediation)
      
      {:provide_hint, {:ok, hint}} ->
        add_to_conversation(state, :system, hint)
      
      {_, {:error, _error}} ->
        add_to_conversation(state, :system, "I encountered an error. Let me try again.")
    end
  end

  defp handle_answer_check_result(state, check_result) do
    is_correct = check_result["is_correct"]
    
    state = update_session_metrics(state, is_correct)
    
    if is_correct do
      # Transition to providing_feedback_correct
      case PSM.transition(state.current_state, :answer_correct) do
        {:ok, new_pedagogical_state} ->
          new_state = %{state | current_state: new_pedagogical_state}
          |> add_to_conversation(:system, check_result["feedback"])
          
          # Check if more topics or complete
          if has_more_topics?(new_state) do
            case PSM.transition(new_state.current_state, :next_topic) do
              {:ok, next_state} ->
                %{new_state | current_state: next_state, current_question: nil}
              _ ->
                new_state
            end
          else
            case PSM.transition(new_state.current_state, :syllabus_complete) do
              {:ok, complete_state} ->
                %{new_state | current_state: complete_state}
                |> handle_state_entry(complete_state)
              _ ->
                new_state
            end
          end
        _ ->
          state
      end
    else
      # Diagnose the error for remediation
      diagnose_error_async(state, check_result)
      state
    end
  end
  
  defp handle_error_diagnosis(state, diagnosis) do
    error_type = diagnosis["error_type"]
    
    event = if error_type == "known", do: :known_error_detected, else: :unknown_error_detected
    
    case PSM.transition(state.current_state, event) do
      {:ok, new_pedagogical_state} ->
        new_state = %{state | current_state: new_pedagogical_state}
        handle_state_entry(new_state, new_pedagogical_state)
      _ ->
        state
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
  
  defp provide_guided_hint_async(state, message) do
    task = ToolTaskSupervisor.async_tool_call(
      Tutor.Tools,
      :provide_hint,
      [state.current_question, message]
    )
    monitor_task(state, task, :provide_hint)
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
  
  defp contains_understanding_indicators?(message) do
    message = String.downcase(message)
    Enum.any?(["understand", "got it", "i see", "makes sense", "ok", "okay", "ready"], fn indicator ->
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
  
  defp handle_state_entry(state, pedagogical_state) do
    case PSM.state_entry_action(pedagogical_state) do
      {:ok, :load_user_context} ->
        # Already loaded in init
        state
        
      {:ok, :deliver_instruction} ->
        # Deliver instruction for current topic
        if state.current_topic do
          state
          |> add_to_conversation(:system, "Let's learn about #{state.current_topic.name}.")
        else
          state
        end
        
      {:ok, :select_question} ->
        # Generate a question
        generate_question_async(state)
        
      {:ok, :trigger_evaluation_tools} ->
        # Already triggered by check_answer_async
        state
        
      {:ok, :update_mastery} ->
        # Update mastery in metrics (already done)
        state
        
      {:ok, :generate_targeted_hint} ->
        # Generate hint for known error
        create_remediation_async(state, %{"type" => "known_error"})
        
      {:ok, :generate_socratic_prompt} ->
        # Generate Socratic prompt
        create_remediation_async(state, %{"type" => "unknown_error"})
        
      {:ok, :start_guided_dialogue} ->
        state
        |> add_to_conversation(:system, "Let's work through this together. What part are you finding difficult?")
        
      {:ok, :generate_summary} ->
        generate_session_summary(state)
        
      :no_action ->
        state
    end
  end
  
  defp has_more_topics?(_state) do
    # Mock: In real implementation, check syllabus progress
    false
  end
  
  defp generate_session_summary(state) do
    metrics = state.session_metrics
    accuracy = if metrics.questions_attempted > 0 do
      Float.round(metrics.correct_answers / metrics.questions_attempted * 100, 1)
    else
      0.0
    end
    
    summary = """
    Great session! Here's your summary:
    - Questions attempted: #{metrics.questions_attempted}
    - Correct answers: #{metrics.correct_answers}
    - Accuracy: #{accuracy}%
    - Topics covered: #{length(metrics.topics_covered)}
    
    Keep up the great work!
    """
    
    add_to_conversation(state, :system, summary)
  end

end