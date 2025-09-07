defmodule TutorEx.Learning.PedagogicalStateMachineTest do
  use ExUnit.Case, async: true
  
  alias TutorEx.Learning.PedagogicalStateMachine, as: PSM

  describe "initial_state/0" do
    test "returns :initializing as the initial state" do
      assert PSM.initial_state() == :initializing
    end
  end

  describe "valid_state?/1" do
    test "returns true for all valid states" do
      valid_states = [
        :initializing,
        :exposition,
        :setting_question,
        :awaiting_answer,
        :evaluating_answer,
        :providing_feedback_correct,
        :remediating_known_error,
        :remediating_unknown_error,
        :guiding_student,
        :session_complete
      ]
      
      for state <- valid_states do
        assert PSM.valid_state?(state), "#{state} should be valid"
      end
    end

    test "returns false for invalid states" do
      invalid_states = [:invalid, :unknown, :random_state]
      
      for state <- invalid_states do
        refute PSM.valid_state?(state), "#{state} should be invalid"
      end
    end
  end

  describe "terminal_state?/1" do
    test "returns true only for :session_complete" do
      assert PSM.terminal_state?(:session_complete)
    end

    test "returns false for all non-terminal states" do
      non_terminal_states = [
        :initializing,
        :exposition,
        :setting_question,
        :awaiting_answer,
        :evaluating_answer,
        :providing_feedback_correct,
        :remediating_known_error,
        :remediating_unknown_error,
        :guiding_student
      ]
      
      for state <- non_terminal_states do
        refute PSM.terminal_state?(state), "#{state} should not be terminal"
      end
    end
  end

  describe "transition/2 - Primary Learning Loop" do
    test "transitions from :initializing to :exposition" do
      assert {:ok, :exposition} = PSM.transition(:initializing, :initialized)
    end

    test "transitions from :exposition to :setting_question" do
      assert {:ok, :setting_question} = PSM.transition(:exposition, :instruction_complete)
    end

    test "transitions from :setting_question to :awaiting_answer" do
      assert {:ok, :awaiting_answer} = PSM.transition(:setting_question, :question_presented)
    end

    test "transitions from :awaiting_answer to :evaluating_answer" do
      assert {:ok, :evaluating_answer} = PSM.transition(:awaiting_answer, :answer_received)
    end

    test "transitions from :evaluating_answer to :providing_feedback_correct" do
      assert {:ok, :providing_feedback_correct} = PSM.transition(:evaluating_answer, :answer_correct)
    end

    test "transitions from :providing_feedback_correct to :exposition for next topic" do
      assert {:ok, :exposition} = PSM.transition(:providing_feedback_correct, :next_topic)
    end

    test "transitions from :providing_feedback_correct to :session_complete" do
      assert {:ok, :session_complete} = PSM.transition(:providing_feedback_correct, :syllabus_complete)
    end
  end

  describe "transition/2 - Remediation Loop" do
    test "transitions from :evaluating_answer to :remediating_known_error" do
      assert {:ok, :remediating_known_error} = PSM.transition(:evaluating_answer, :known_error_detected)
    end

    test "transitions from :remediating_known_error to :awaiting_answer" do
      assert {:ok, :awaiting_answer} = PSM.transition(:remediating_known_error, :retry_question)
    end
  end

  describe "transition/2 - Guidance Loop" do
    test "transitions from :evaluating_answer to :remediating_unknown_error" do
      assert {:ok, :remediating_unknown_error} = PSM.transition(:evaluating_answer, :unknown_error_detected)
    end

    test "transitions from :remediating_unknown_error to :guiding_student" do
      assert {:ok, :guiding_student} = PSM.transition(:remediating_unknown_error, :guidance_complete)
    end

    test "transitions from :guiding_student to :awaiting_answer" do
      assert {:ok, :awaiting_answer} = PSM.transition(:guiding_student, :retry_question)
    end
  end

  describe "transition/2 - Invalid Transitions" do
    test "returns error for invalid transitions" do
      invalid_transitions = [
        {:initializing, :answer_received},
        {:exposition, :answer_correct},
        {:awaiting_answer, :initialized},
        {:session_complete, :initialized},
        {:session_complete, :next_topic}
      ]
      
      for {state, event} <- invalid_transitions do
        assert {:error, :invalid_transition} = PSM.transition(state, event),
               "Transition from #{state} with #{event} should be invalid"
      end
    end

    test "returns error for invalid state" do
      assert {:error, :invalid_transition} = PSM.transition(:invalid_state, :initialized)
    end

    test "returns error for invalid event" do
      assert {:error, :invalid_transition} = PSM.transition(:initializing, :invalid_event)
    end
  end

  describe "valid_events/1" do
    test "returns correct events for each state" do
      assert [:initialized] = PSM.valid_events(:initializing)
      assert [:instruction_complete] = PSM.valid_events(:exposition)
      assert [:question_presented] = PSM.valid_events(:setting_question)
      assert [:answer_received] = PSM.valid_events(:awaiting_answer)
      assert events = PSM.valid_events(:evaluating_answer)
      assert :answer_correct in events
      assert :known_error_detected in events
      assert :unknown_error_detected in events
      assert [:next_topic, :syllabus_complete] = PSM.valid_events(:providing_feedback_correct)
      assert [:retry_question] = PSM.valid_events(:remediating_known_error)
      assert [:guidance_complete] = PSM.valid_events(:remediating_unknown_error)
      assert [:retry_question] = PSM.valid_events(:guiding_student)
      assert [] = PSM.valid_events(:session_complete)
    end
  end

  describe "flow_pattern/1" do
    test "returns correct flow pattern for states" do
      assert :primary_learning = PSM.flow_pattern(:initializing)
      assert :primary_learning = PSM.flow_pattern(:exposition)
      assert :primary_learning = PSM.flow_pattern(:setting_question)
      assert :primary_learning = PSM.flow_pattern(:awaiting_answer)
      assert :primary_learning = PSM.flow_pattern(:evaluating_answer)
      assert :primary_learning = PSM.flow_pattern(:providing_feedback_correct)
      assert :remediation = PSM.flow_pattern(:remediating_known_error)
      assert :guidance = PSM.flow_pattern(:remediating_unknown_error)
      assert :guidance = PSM.flow_pattern(:guiding_student)
      assert :terminal = PSM.flow_pattern(:session_complete)
    end
  end

  describe "state_description/1" do
    test "returns meaningful descriptions for all states" do
      for state <- PSM.valid_states() do
        description = PSM.state_description(state)
        assert is_binary(description)
        assert String.length(description) > 0
      end
    end
  end

  describe "state_entry_action/1" do
    test "returns appropriate actions for states" do
      assert {:ok, :load_user_context} = PSM.state_entry_action(:initializing)
      assert {:ok, :deliver_instruction} = PSM.state_entry_action(:exposition)
      assert {:ok, :select_question} = PSM.state_entry_action(:setting_question)
      assert :no_action = PSM.state_entry_action(:awaiting_answer)
      assert {:ok, :trigger_evaluation_tools} = PSM.state_entry_action(:evaluating_answer)
      assert {:ok, :update_mastery} = PSM.state_entry_action(:providing_feedback_correct)
      assert {:ok, :generate_targeted_hint} = PSM.state_entry_action(:remediating_known_error)
      assert {:ok, :generate_socratic_prompt} = PSM.state_entry_action(:remediating_unknown_error)
      assert {:ok, :start_guided_dialogue} = PSM.state_entry_action(:guiding_student)
      assert {:ok, :generate_summary} = PSM.state_entry_action(:session_complete)
    end
  end

  describe "accepts_user_input?/1" do
    test "returns true for states that accept user input" do
      assert PSM.accepts_user_input?(:awaiting_answer)
      assert PSM.accepts_user_input?(:guiding_student)
      assert PSM.accepts_user_input?(:exposition)
    end

    test "returns false for states that don't accept user input" do
      refute PSM.accepts_user_input?(:initializing)
      refute PSM.accepts_user_input?(:setting_question)
      refute PSM.accepts_user_input?(:evaluating_answer)
      refute PSM.accepts_user_input?(:providing_feedback_correct)
      refute PSM.accepts_user_input?(:remediating_known_error)
      refute PSM.accepts_user_input?(:remediating_unknown_error)
      refute PSM.accepts_user_input?(:session_complete)
    end
  end

  describe "requires_async_tools?/1" do
    test "returns true for states requiring async tools" do
      assert PSM.requires_async_tools?(:evaluating_answer)
      assert PSM.requires_async_tools?(:remediating_known_error)
      assert PSM.requires_async_tools?(:remediating_unknown_error)
    end

    test "returns false for states not requiring async tools" do
      refute PSM.requires_async_tools?(:initializing)
      refute PSM.requires_async_tools?(:exposition)
      refute PSM.requires_async_tools?(:setting_question)
      refute PSM.requires_async_tools?(:awaiting_answer)
      refute PSM.requires_async_tools?(:providing_feedback_correct)
      refute PSM.requires_async_tools?(:guiding_student)
      refute PSM.requires_async_tools?(:session_complete)
    end
  end

  describe "Complete flow scenarios" do
    test "can complete a full successful learning cycle" do
      state = PSM.initial_state()
      
      # Initialize session
      assert {:ok, state} = PSM.transition(state, :initialized)
      assert state == :exposition
      
      # Present question
      assert {:ok, state} = PSM.transition(state, :instruction_complete)
      assert state == :setting_question
      
      assert {:ok, state} = PSM.transition(state, :question_presented)
      assert state == :awaiting_answer
      
      # Answer correctly
      assert {:ok, state} = PSM.transition(state, :answer_received)
      assert state == :evaluating_answer
      
      assert {:ok, state} = PSM.transition(state, :answer_correct)
      assert state == :providing_feedback_correct
      
      # Complete session
      assert {:ok, state} = PSM.transition(state, :syllabus_complete)
      assert state == :session_complete
      assert PSM.terminal_state?(state)
    end

    test "can handle remediation flow for known errors" do
      # Start from evaluating answer
      state = :evaluating_answer
      
      # Detect known error
      assert {:ok, state} = PSM.transition(state, :known_error_detected)
      assert state == :remediating_known_error
      
      # Retry question
      assert {:ok, state} = PSM.transition(state, :retry_question)
      assert state == :awaiting_answer
      
      # Can continue with another answer
      assert {:ok, state} = PSM.transition(state, :answer_received)
      assert state == :evaluating_answer
    end

    test "can handle guidance flow for unknown errors" do
      # Start from evaluating answer
      state = :evaluating_answer
      
      # Detect unknown error
      assert {:ok, state} = PSM.transition(state, :unknown_error_detected)
      assert state == :remediating_unknown_error
      
      # Start guided dialogue
      assert {:ok, state} = PSM.transition(state, :guidance_complete)
      assert state == :guiding_student
      
      # Retry question after guidance
      assert {:ok, state} = PSM.transition(state, :retry_question)
      assert state == :awaiting_answer
    end
  end
end