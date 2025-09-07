defmodule TutorEx.Learning.AdaptiveInterventionTest do
  use ExUnit.Case, async: true
  
  import Mox
  
  alias TutorEx.Learning.AdaptiveIntervention
  alias Tutor.Tools

  setup :set_mox_from_context
  setup :verify_on_exit!

  describe "generate_intervention/3" do
    test "generates subtle intervention for first attempt" do
      diagnosis = %{
        error_type: :known,
        error_description: "Arithmetic error",
        confidence: 0.8
      }
      
      question = %{
        "text" => "What is 5 + 3?",
        "topic" => "arithmetic"
      }
      
      Tutor.Tools.Mock
      |> expect(:provide_hint, fn ^question, prompt ->
        assert String.contains?(prompt, "subtle hint")
        {:ok, "Take another look at the numbers you're adding."}
      end)

      assert {:ok, intervention} = AdaptiveIntervention.generate_intervention(diagnosis, 1, question)
      
      assert intervention.level == :subtle
      assert is_binary(intervention.content)
      assert intervention.next_level == :moderate
    end

    test "generates moderate intervention for second attempt with high confidence" do
      diagnosis = %{
        error_type: :known,
        error_description: "Sign error",
        confidence: 0.9
      }
      
      question = %{"text" => "Solve -2x = 6", "topic" => "algebra"}
      
      Tutor.Tools.Mock
      |> expect(:provide_hint, fn ^question, prompt ->
        assert String.contains?(prompt, "clearer guidance")
        {:ok, "Remember to consider the negative sign when isolating x."}
      end)

      assert {:ok, intervention} = AdaptiveIntervention.generate_intervention(diagnosis, 2, question)
      
      assert intervention.level == :moderate
      assert intervention.next_level == :explicit
    end

    test "generates explicit intervention for multiple attempts" do
      diagnosis = %{error_type: :unknown}
      question = %{"text" => "Factor x² - 5x + 6", "topic" => "algebra"}
      
      Tutor.Tools.Mock
      |> expect(:provide_hint, fn ^question, prompt ->
        assert String.contains?(prompt, "explicit instructions")
        {:ok, "Use the formula: find two numbers that multiply to 6 and add to -5."}
      end)

      assert {:ok, intervention} = AdaptiveIntervention.generate_intervention(diagnosis, 4, question)
      
      assert intervention.level == :explicit
      assert intervention.next_level == :worked_example
    end

    test "generates worked example for many attempts" do
      diagnosis = %{error_type: :known}
      question = %{"text" => "Simplify 2/3 + 1/4", "topic" => "fractions"}
      
      Tutor.Tools.Mock
      |> expect(:provide_hint, fn ^question, prompt ->
        assert String.contains?(prompt, "worked example")
        {:ok, "Example: 1/2 + 1/3 = 3/6 + 2/6 = 5/6. Now apply this to your problem."}
      end)

      assert {:ok, intervention} = AdaptiveIntervention.generate_intervention(diagnosis, 5, question)
      
      assert intervention.level == :worked_example
      assert intervention.next_level == nil
    end

    test "handles LLM failure" do
      diagnosis = %{error_type: :known}
      question = %{"text" => "Test", "topic" => "test"}
      
      Tutor.Tools.Mock
      |> expect(:provide_hint, fn _q, _p ->
        {:error, "LLM unavailable"}
      end)

      assert {:error, "LLM unavailable"} = AdaptiveIntervention.generate_intervention(diagnosis, 1, question)
    end
  end

  describe "generate_socratic_prompt/2" do
    test "generates contextual Socratic question" do
      question = %{
        "text" => "Find the derivative of x²",
        "topic" => "calculus"
      }
      
      student_response = "I'm not sure where to start"
      
      Tutor.Tools.Mock
      |> expect(:provide_hint, fn ^question, prompt ->
        assert String.contains?(prompt, student_response)
        assert String.contains?(prompt, "Socratic question")
        assert String.contains?(prompt, "examine their reasoning")
        
        {:ok, "What do you know about the power rule for derivatives?"}
      end)

      assert {:ok, prompt} = AdaptiveIntervention.generate_socratic_prompt(question, student_response)
      assert is_binary(prompt)
      assert String.contains?(prompt, "power rule")
    end

    test "handles LLM error" do
      question = %{"text" => "Test", "topic" => "test"}
      student_response = "I'm confused"
      
      Tutor.Tools.Mock
      |> expect(:provide_hint, fn _q, _p ->
        {:error, "Service error"}
      end)

      assert {:error, "Service error"} = AdaptiveIntervention.generate_socratic_prompt(question, student_response)
    end
  end

  describe "create_hint_sequence/1" do
    test "creates progressive hint sequence" do
      question = %{
        "text" => "Solve the quadratic equation x² - 7x + 12 = 0",
        "topic" => "algebra"
      }
      
      Tutor.Tools.Mock
      |> expect(:provide_hint, fn ^question, prompt ->
        assert String.contains?(prompt, "sequence of 4")
        assert String.contains?(prompt, "progressively more helpful")
        
        {:ok, """
        1. Think about what two numbers multiply to 12 and add to -7
        2. You need to factor this quadratic expression
        3. Use the factoring method: (x - a)(x - b) = 0 where a and b are your numbers
        4. Step by step: x² - 7x + 12 = (x - 3)(x - 4) = 0, so x = 3 or x = 4
        """}
      end)

      assert {:ok, hints} = AdaptiveIntervention.create_hint_sequence(question)
      assert is_list(hints)
      assert length(hints) == 4
      assert Enum.any?(hints, &String.contains?(&1, "multiply"))
      assert Enum.any?(hints, &String.contains?(&1, "factor"))
      assert Enum.any?(hints, &String.contains?(&1, "Step by step"))
    end

    test "handles malformed LLM response" do
      question = %{"text" => "Test", "topic" => "test"}
      
      Tutor.Tools.Mock
      |> expect(:provide_hint, fn _q, _p ->
        {:ok, "No numbered hints here"}
      end)

      assert {:ok, hints} = AdaptiveIntervention.create_hint_sequence(question)
      assert is_list(hints)
      assert length(hints) == 1
      assert "No numbered hints here" in hints
    end
  end

  describe "generate_guided_dialogue/3" do
    test "generates contextual dialogue for turn 1" do
      question = %{
        "text" => "What is the area of a rectangle with length 8 and width 5?",
        "topic" => "geometry"
      }
      
      student_message = "I don't know how to start"
      dialogue_turn = 1
      
      Tutor.Tools.Mock
      |> expect(:provide_hint, fn ^question, prompt ->
        assert String.contains?(prompt, "turn 1")
        assert String.contains?(prompt, student_message)
        assert String.contains?(prompt, "understanding what they find difficult")
        
        {:ok, "I understand this can be tricky. Can you tell me what you think area means?"}
      end)

      assert {:ok, response} = AdaptiveIntervention.generate_guided_dialogue(question, student_message, dialogue_turn)
      assert is_binary(response)
      assert String.contains?(response, "area means")
    end

    test "generates appropriate dialogue for later turns" do
      question = %{"text" => "Calculate 15% of 200", "topic" => "percentages"}
      student_message = "I think I need to multiply by 15"
      dialogue_turn = 3
      
      Tutor.Tools.Mock
      |> expect(:provide_hint, fn ^question, prompt ->
        assert String.contains?(prompt, "turn 3")
        assert String.contains?(prompt, "right method")
        {:ok, "You're on the right track! But what do you need to do to 15 first?"}
      end)

      assert {:ok, response} = AdaptiveIntervention.generate_guided_dialogue(question, student_message, dialogue_turn)
      assert String.contains?(response, "right track")
    end

    test "handles high turn numbers" do
      question = %{"text" => "Test", "topic" => "test"}
      student_message = "Still confused"
      dialogue_turn = 10
      
      Tutor.Tools.Mock
      |> expect(:provide_hint, fn ^question, prompt ->
        assert String.contains?(prompt, "turn 10")
        assert String.contains?(prompt, "problem-solving process")
        {:ok, "Let's try a different approach. What specific part is confusing you?"}
      end)

      assert {:ok, response} = AdaptiveIntervention.generate_guided_dialogue(question, student_message, dialogue_turn)
      assert String.contains?(response, "different approach")
    end
  end

  describe "generate_known_error_remediation/2" do
    test "generates targeted remediation for known error patterns" do
      error_pattern = %{
        description: "Added denominators instead of finding common denominator",
        category: :fraction_operations,
        remediation_strategy: "Find common denominator first"
      }
      
      question = %{
        "text" => "Add 1/3 + 1/4",
        "topic" => "fractions"
      }
      
      Tutor.Tools.Mock
      |> expect(:create_remediation, fn topic, remediation_data ->
        assert topic == "fractions"
        assert remediation_data["error_description"] == error_pattern.description
        assert remediation_data["remediation_strategy"] == error_pattern.remediation_strategy
        
        {:ok, "I see you added the denominators. Remember: when adding fractions, find a common denominator first, then add only the numerators."}
      end)

      assert {:ok, remediation} = AdaptiveIntervention.generate_known_error_remediation(error_pattern, question)
      assert is_binary(remediation)
      assert String.contains?(remediation, "common denominator")
    end
  end

  describe "generate_unknown_error_remediation/2" do
    test "generates Socratic remediation for unknown errors" do
      question = %{
        "text" => "Solve for x: 3x + 7 = 22",
        "topic" => "algebra"
      }
      
      student_answer = "x = 29"
      
      Tutor.Tools.Mock
      |> expect(:create_remediation, fn topic, remediation_data ->
        assert topic == "algebra"
        assert remediation_data["student_answer"] == student_answer
        assert remediation_data["error_type"] == "unknown"
        assert remediation_data["approach"] == "socratic_questioning"
        
        {:ok, "Let's think about this step by step. When you have 3x + 7 = 22, what should be your first step?"}
      end)

      assert {:ok, remediation} = AdaptiveIntervention.generate_unknown_error_remediation(question, student_answer)
      assert is_binary(remediation)
      assert String.contains?(remediation, "step by step")
    end
  end

  describe "helper functions" do
    test "determine_intervention_level/2 returns appropriate levels" do
      # These are tested indirectly through generate_intervention/3
      # The logic is:
      # - Attempt 1: :subtle
      # - Attempt 2 with high confidence: :moderate  
      # - Attempt 2 with low confidence: :subtle
      # - Attempt 3: :moderate
      # - Attempt 4: :explicit
      # - Attempt 5+: :worked_example
      
      # Test through public interface
      diagnosis_high_conf = %{confidence: 0.8}
      diagnosis_low_conf = %{confidence: 0.3}
      question = %{"text" => "Test", "topic" => "test"}
      
      Tutor.Tools.Mock
      |> expect(:provide_hint, 2, fn _q, prompt ->
        {:ok, "Test response"}
      end)

      # High confidence, attempt 2 -> moderate
      {:ok, intervention} = AdaptiveIntervention.generate_intervention(diagnosis_high_conf, 2, question)
      assert intervention.level == :moderate
      
      # Low confidence, attempt 2 -> subtle  
      {:ok, intervention} = AdaptiveIntervention.generate_intervention(diagnosis_low_conf, 2, question)
      assert intervention.level == :subtle
    end

    test "generate_follow_up/2 returns appropriate questions" do
      # These are tested through the intervention generation
      question = %{"text" => "Test problem", "focus" => "variables"}
      
      Tutor.Tools.Mock
      |> expect(:provide_hint, fn _q, _p -> {:ok, "test"} end)

      {:ok, intervention} = AdaptiveIntervention.generate_intervention(%{}, 1, question)
      assert is_binary(intervention.follow_up_question)
    end

    test "get_next_level/1 returns correct progression" do
      # Test through intervention generation
      question = %{"text" => "Test", "topic" => "test"}
      
      Tutor.Tools.Mock
      |> expect(:provide_hint, 4, fn _q, _p -> {:ok, "test"} end)

      {:ok, subtle} = AdaptiveIntervention.generate_intervention(%{}, 1, question)
      assert subtle.next_level == :moderate
      
      {:ok, moderate} = AdaptiveIntervention.generate_intervention(%{}, 3, question)
      assert moderate.next_level == :explicit
      
      {:ok, explicit} = AdaptiveIntervention.generate_intervention(%{}, 4, question)
      assert explicit.next_level == :worked_example
      
      {:ok, worked} = AdaptiveIntervention.generate_intervention(%{}, 5, question)
      assert worked.next_level == nil
    end
  end
end