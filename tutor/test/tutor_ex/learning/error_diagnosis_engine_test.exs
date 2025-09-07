defmodule TutorEx.Learning.ErrorDiagnosisEngineTest do
  use ExUnit.Case, async: true
  
  import Mox
  
  alias TutorEx.Learning.ErrorDiagnosisEngine
  alias Tutor.Tools

  # Set up mocks
  setup :set_mox_from_context
  setup :verify_on_exit!

  describe "diagnose_error/3" do
    test "returns known error diagnosis when LLM identifies error" do
      question = %{
        "text" => "What is 2 + 2?",
        "topic" => "arithmetic"
      }
      
      check_result = %{
        "correct_answer" => "4",
        "is_correct" => false
      }
      
      student_answer = "6"
      
      # Mock LLM response
      Tutor.Tools.Mock
      |> expect(:diagnose_error, fn _q, _data ->
        {:ok, %{
          "error_identified" => true,
          "error_category" => "computational",
          "error_description" => "Addition miscalculation",
          "misconception" => "Student may have confused addition with multiplication",
          "confidence" => 0.85,
          "suggested_approach" => "Review basic addition facts"
        }}
      end)

      assert {:ok, diagnosis} = ErrorDiagnosisEngine.diagnose_error(question, check_result, student_answer)
      
      assert diagnosis.error_type == :known
      assert diagnosis.error_category == "computational"
      assert diagnosis.error_description == "Addition miscalculation"
      assert diagnosis.confidence == 0.85
      assert diagnosis.misconception == "Student may have confused addition with multiplication"
      assert diagnosis.suggested_remediation == "Review basic addition facts"
    end

    test "returns unknown error diagnosis when LLM doesn't identify specific error" do
      question = %{"text" => "Complex problem", "topic" => "calculus"}
      check_result = %{"correct_answer" => "42", "is_correct" => false}
      student_answer = "wrong"
      
      Tutor.Tools.Mock
      |> expect(:diagnose_error, fn _q, _data ->
        {:ok, %{
          "error_identified" => false,
          "confidence" => 0.2,
          "suggested_approach" => "Let's work through this step by step"
        }}
      end)

      assert {:ok, diagnosis} = ErrorDiagnosisEngine.diagnose_error(question, check_result, student_answer)
      
      assert diagnosis.error_type == :unknown
      assert diagnosis.confidence == 0.2
    end

    test "handles LLM failure gracefully" do
      question = %{"text" => "Test question", "topic" => "test"}
      check_result = %{"correct_answer" => "test", "is_correct" => false}
      student_answer = "wrong"
      
      Tutor.Tools.Mock
      |> expect(:diagnose_error, fn _q, _data ->
        {:error, "LLM service unavailable"}
      end)

      assert {:ok, diagnosis} = ErrorDiagnosisEngine.diagnose_error(question, check_result, student_answer)
      
      assert diagnosis.error_type == :unknown
      assert diagnosis.confidence == 0.0
      assert diagnosis.suggested_remediation == "Let's work through this problem step by step."
    end

    test "parses confidence correctly" do
      question = %{"text" => "Test", "topic" => "test"}
      check_result = %{"correct_answer" => "test", "is_correct" => false}
      student_answer = "wrong"
      
      # Test with string confidence
      Tutor.Tools.Mock
      |> expect(:diagnose_error, fn _q, _data ->
        {:ok, %{
          "error_identified" => true,
          "confidence" => "0.75"
        }}
      end)

      assert {:ok, diagnosis} = ErrorDiagnosisEngine.diagnose_error(question, check_result, student_answer)
      assert diagnosis.confidence == 0.75
    end
  end

  describe "get_common_misconceptions/1" do
    test "requests misconceptions from LLM" do
      topic = "fractions"
      
      Tutor.Tools.Mock
      |> expect(:explain_concept, fn ^topic, prompt ->
        assert String.contains?(prompt, "common misconceptions")
        assert String.contains?(prompt, topic)
        
        {:ok, """
        Common misconceptions in fractions:
        1. Adding denominators when adding fractions
        2. Cross-multiplying incorrectly
        3. Not finding common denominators
        """}
      end)

      assert {:ok, misconceptions} = ErrorDiagnosisEngine.get_common_misconceptions(topic)
      assert is_list(misconceptions)
      assert length(misconceptions) > 0
      assert Enum.any?(misconceptions, &String.contains?(&1, "denominators"))
    end

    test "handles LLM failure" do
      topic = "algebra"
      
      Tutor.Tools.Mock
      |> expect(:explain_concept, fn _topic, _prompt ->
        {:error, "Service error"}
      end)

      assert {:error, "Service error"} = ErrorDiagnosisEngine.get_common_misconceptions(topic)
    end
  end

  describe "generate_targeted_remediation/2" do
    test "generates remediation using LLM" do
      diagnosis = %{
        error_type: :known,
        error_description: "Sign error in algebra",
        misconception: "Student confused positive and negative signs"
      }
      
      question = %{
        "text" => "Solve: -2x + 5 = 11",
        "topic" => "algebra",
        "difficulty" => "foundation"
      }
      
      Tutor.Tools.Mock
      |> expect(:create_remediation, fn topic, remediation_data ->
        assert topic == "algebra"
        assert remediation_data.error_type == :known
        assert remediation_data.error_description == "Sign error in algebra"
        
        {:ok, "Let's review sign rules in algebra. When you have -2x, remember that..."}
      end)

      assert {:ok, remediation} = ErrorDiagnosisEngine.generate_targeted_remediation(diagnosis, question)
      assert is_binary(remediation)
      assert String.contains?(remediation, "sign rules")
    end

    test "handles LLM failure" do
      diagnosis = %{error_type: :unknown}
      question = %{"topic" => "test"}
      
      Tutor.Tools.Mock
      |> expect(:create_remediation, fn _topic, _data ->
        {:error, "Generation failed"}
      end)

      assert {:error, "Generation failed"} = ErrorDiagnosisEngine.generate_targeted_remediation(diagnosis, question)
    end
  end

  describe "generate_hint/2" do
    test "generates hint using LLM" do
      question = %{
        "text" => "Find the area of a circle with radius 5",
        "topic" => "geometry"
      }
      
      student_attempt = "25"
      
      Tutor.Tools.Mock
      |> expect(:provide_hint, fn ^question, prompt ->
        assert String.contains?(prompt, student_attempt)
        assert String.contains?(prompt, "helpful hint")
        
        {:ok, "Remember the formula for area of a circle: A = πr²"}
      end)

      assert {:ok, hint} = ErrorDiagnosisEngine.generate_hint(question, student_attempt)
      assert is_binary(hint)
      assert String.contains?(hint, "πr²")
    end

    test "generates hint without student attempt" do
      question = %{"text" => "Solve for x", "topic" => "algebra"}
      
      Tutor.Tools.Mock
      |> expect(:provide_hint, fn ^question, prompt ->
        assert String.contains?(prompt, "hasn't attempted")
        {:ok, "Start by identifying the variable you need to solve for"}
      end)

      assert {:ok, hint} = ErrorDiagnosisEngine.generate_hint(question)
      assert String.contains?(hint, "variable")
    end
  end

  describe "generate_worked_example/2" do
    test "generates worked example using LLM" do
      topic = "fractions"
      error_type = "denominator_addition"
      
      Tutor.Tools.Mock
      |> expect(:explain_concept, fn ^topic, prompt ->
        assert String.contains?(prompt, "worked example")
        assert String.contains?(prompt, error_type)
        
        {:ok, """
        Example: Add 1/3 + 1/4
        Step 1: Find LCD = 12
        Step 2: Convert fractions: 4/12 + 3/12
        Step 3: Add numerators: 7/12
        """}
      end)

      assert {:ok, example} = ErrorDiagnosisEngine.generate_worked_example(topic, error_type)
      assert is_binary(example)
      assert String.contains?(example, "Step 1")
      assert String.contains?(example, "LCD")
    end
  end

  # Test helper functions
  describe "private helper functions" do
    test "parse_confidence handles various formats" do
      # Test via diagnose_error since parse_confidence is private
      question = %{"text" => "Test", "topic" => "test"}
      check_result = %{"correct_answer" => "test", "is_correct" => false}
      student_answer = "wrong"
      
      # Test nil confidence
      Tutor.Tools.Mock
      |> expect(:diagnose_error, fn _q, _data ->
        {:ok, %{"error_identified" => true, "confidence" => nil}}
      end)

      assert {:ok, diagnosis} = ErrorDiagnosisEngine.diagnose_error(question, check_result, student_answer)
      assert diagnosis.confidence == 0.5
    end

    test "parse_misconceptions handles text response" do
      topic = "test"
      
      Tutor.Tools.Mock
      |> expect(:explain_concept, fn _topic, _prompt ->
        {:ok, "Line 1\nLine 2\n\nLine 4"}
      end)

      assert {:ok, misconceptions} = ErrorDiagnosisEngine.get_common_misconceptions(topic)
      assert length(misconceptions) == 3  # Empty lines filtered out
      assert "Line 1" in misconceptions
      assert "Line 2" in misconceptions
      assert "Line 4" in misconceptions
    end
  end
end