defmodule TutorEx.Learning.PedagogicalStateMachine do
  @moduledoc """
  Implements the pedagogical finite state machine for managing tutoring session flow.
  
  Each state represents a distinct mode of conversation, with transitions triggered
  by events like user input or asynchronous tool results.
  """

  @type state :: :initializing | :exposition | :setting_question | :awaiting_answer |
                 :evaluating_answer | :providing_feedback_correct | :remediating_known_error |
                 :remediating_unknown_error | :guiding_student | :session_complete | :awaiting_tool_result

  @type event :: :initialized | :instruction_complete | :question_presented | :answer_received |
                 :answer_correct | :known_error_detected | :unknown_error_detected |
                 :guidance_complete | :retry_question | :syllabus_complete | :next_topic | :tool_requested | :tool_completed

  @type transition_result :: {:ok, state} | {:error, :invalid_transition}

  @doc """
  Returns the initial state for a new session.
  """
  @spec initial_state() :: state()
  def initial_state, do: :initializing

  @doc """
  Returns all valid states in the state machine.
  """
  @spec valid_states() :: [state()]
  def valid_states do
    [
      :initializing,
      :exposition,
      :setting_question,
      :awaiting_answer,
      :evaluating_answer,
      :providing_feedback_correct,
      :remediating_known_error,
      :remediating_unknown_error,
      :guiding_student,
      :session_complete,
      :awaiting_tool_result
    ]
  end

  @doc """
  Validates if a state is valid.
  """
  @spec valid_state?(state()) :: boolean()
  def valid_state?(state), do: state in valid_states()

  @doc """
  Determines if a state is terminal (no further transitions possible).
  """
  @spec terminal_state?(state()) :: boolean()
  def terminal_state?(:session_complete), do: true
  def terminal_state?(_), do: false

  @doc """
  Transitions from current state based on event.
  Returns {:ok, new_state} or {:error, :invalid_transition}.
  """
  @spec transition(state(), event()) :: transition_result()
  
  # From :initializing
  def transition(:initializing, :initialized), do: {:ok, :exposition}
  
  # From :exposition
  def transition(:exposition, :instruction_complete), do: {:ok, :setting_question}
  def transition(:exposition, :tool_requested), do: {:ok, :awaiting_tool_result}
  
  # From :setting_question
  def transition(:setting_question, :question_presented), do: {:ok, :awaiting_answer}
  def transition(:setting_question, :tool_requested), do: {:ok, :awaiting_tool_result}
  
  # From :awaiting_answer
  def transition(:awaiting_answer, :answer_received), do: {:ok, :evaluating_answer}
  
  # From :evaluating_answer
  def transition(:evaluating_answer, :answer_correct), do: {:ok, :providing_feedback_correct}
  def transition(:evaluating_answer, :known_error_detected), do: {:ok, :remediating_known_error}
  def transition(:evaluating_answer, :unknown_error_detected), do: {:ok, :remediating_unknown_error}
  
  # From :providing_feedback_correct
  def transition(:providing_feedback_correct, :next_topic), do: {:ok, :exposition}
  def transition(:providing_feedback_correct, :syllabus_complete), do: {:ok, :session_complete}
  
  # From :remediating_known_error
  def transition(:remediating_known_error, :retry_question), do: {:ok, :awaiting_answer}
  
  # From :remediating_unknown_error
  def transition(:remediating_unknown_error, :guidance_complete), do: {:ok, :guiding_student}
  
  # From :guiding_student
  def transition(:guiding_student, :retry_question), do: {:ok, :awaiting_answer}
  
  # From :awaiting_tool_result (can return to various states based on context)
  def transition(:awaiting_tool_result, :tool_completed), do: {:ok, :exposition}
  def transition(:awaiting_tool_result, :question_presented), do: {:ok, :awaiting_answer}
  def transition(:awaiting_tool_result, :instruction_complete), do: {:ok, :setting_question}
  
  # Invalid transitions
  def transition(_, _), do: {:error, :invalid_transition}

  @doc """
  Returns valid events for a given state.
  """
  @spec valid_events(state()) :: [event()]
  def valid_events(:initializing), do: [:initialized]
  def valid_events(:exposition), do: [:instruction_complete]
  def valid_events(:setting_question), do: [:question_presented]
  def valid_events(:awaiting_answer), do: [:answer_received]
  def valid_events(:evaluating_answer), do: [:answer_correct, :known_error_detected, :unknown_error_detected]
  def valid_events(:providing_feedback_correct), do: [:next_topic, :syllabus_complete]
  def valid_events(:remediating_known_error), do: [:retry_question]
  def valid_events(:remediating_unknown_error), do: [:guidance_complete]
  def valid_events(:guiding_student), do: [:retry_question]
  def valid_events(:awaiting_tool_result), do: [:tool_completed, :question_presented, :instruction_complete]
  def valid_events(:session_complete), do: []

  @doc """
  Returns the flow pattern for a given state.
  """
  @spec flow_pattern(state()) :: :primary_learning | :remediation | :guidance | :terminal
  def flow_pattern(state) when state in [:initializing, :exposition, :setting_question, 
                                          :awaiting_answer, :evaluating_answer, 
                                          :providing_feedback_correct, :awaiting_tool_result], do: :primary_learning
  def flow_pattern(:remediating_known_error), do: :remediation
  def flow_pattern(state) when state in [:remediating_unknown_error, :guiding_student], do: :guidance
  def flow_pattern(:session_complete), do: :terminal

  @doc """
  Returns a human-readable description of the state.
  """
  @spec state_description(state()) :: String.t()
  def state_description(:initializing), do: "Setting up session"
  def state_description(:exposition), do: "Teaching concept"
  def state_description(:setting_question), do: "Preparing question"
  def state_description(:awaiting_answer), do: "Waiting for student response"
  def state_description(:evaluating_answer), do: "Evaluating answer"
  def state_description(:providing_feedback_correct), do: "Providing positive feedback"
  def state_description(:remediating_known_error), do: "Addressing specific misconception"
  def state_description(:remediating_unknown_error), do: "Providing general guidance"
  def state_description(:guiding_student), do: "Guiding through dialogue"
  def state_description(:awaiting_tool_result), do: "Processing request"
  def state_description(:session_complete), do: "Session complete"

  @doc """
  Returns the action to take when entering a state.
  """
  @spec state_entry_action(state()) :: {:ok, atom()} | :no_action
  def state_entry_action(:initializing), do: {:ok, :load_user_context}
  def state_entry_action(:exposition), do: {:ok, :deliver_instruction}
  def state_entry_action(:setting_question), do: {:ok, :select_question}
  def state_entry_action(:awaiting_answer), do: :no_action
  def state_entry_action(:evaluating_answer), do: {:ok, :trigger_evaluation_tools}
  def state_entry_action(:providing_feedback_correct), do: {:ok, :update_mastery}
  def state_entry_action(:remediating_known_error), do: {:ok, :generate_targeted_hint}
  def state_entry_action(:remediating_unknown_error), do: {:ok, :generate_socratic_prompt}
  def state_entry_action(:guiding_student), do: {:ok, :start_guided_dialogue}
  def state_entry_action(:awaiting_tool_result), do: :no_action
  def state_entry_action(:session_complete), do: {:ok, :generate_summary}

  @doc """
  Determines if the state allows user input.
  """
  @spec accepts_user_input?(state()) :: boolean()
  def accepts_user_input?(:awaiting_answer), do: true
  def accepts_user_input?(:guiding_student), do: true
  def accepts_user_input?(:exposition), do: true  # For clarifying questions
  def accepts_user_input?(:awaiting_tool_result), do: false  # Waiting for async processing
  def accepts_user_input?(_), do: false

  @doc """
  Determines if the state requires async tool execution.
  """
  @spec requires_async_tools?(state()) :: boolean()
  def requires_async_tools?(:evaluating_answer), do: true
  def requires_async_tools?(:remediating_known_error), do: true
  def requires_async_tools?(:remediating_unknown_error), do: true
  def requires_async_tools?(:awaiting_tool_result), do: true
  def requires_async_tools?(_), do: false
end