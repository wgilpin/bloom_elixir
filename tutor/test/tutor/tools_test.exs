defmodule Tutor.ToolsTest do
  use ExUnit.Case, async: true
  
  alias Tutor.Tools
  
  describe "generate_question/1" do
    test "generates a question with required fields" do
      topic = %{id: 1, name: "Addition"}
      result = Tools.generate_question(topic)
      
      assert is_map(result)
      assert result["text"] != nil
      assert result["type"] != nil
      assert result["correct_answer"] != nil
      assert result["options"] != nil
      assert result["difficulty"] != nil
      
      assert String.contains?(result["text"], topic.name)
    end
  end
  
  describe "check_answer/2" do
    test "correctly identifies correct answer" do
      question = %{"correct_answer" => "4"}
      result = Tools.check_answer(question, "4")
      
      assert result["is_correct"] == true
      assert result["feedback"] != nil
      assert String.contains?(result["feedback"], "correct")
    end
    
    test "correctly identifies incorrect answer" do
      question = %{"correct_answer" => "4"}
      result = Tools.check_answer(question, "5")
      
      assert result["is_correct"] == false
      assert result["feedback"] != nil
      assert String.contains?(result["feedback"], "Not quite")
    end
    
    test "handles case-insensitive answers" do
      question = %{"correct_answer" => "Paris"}
      result = Tools.check_answer(question, "paris")
      
      assert result["is_correct"] == true
    end
    
    test "handles whitespace in answers" do
      question = %{"correct_answer" => "4"}
      result = Tools.check_answer(question, "  4  ")
      
      assert result["is_correct"] == true
    end
  end
  
  describe "diagnose_error/2" do
    test "returns error diagnosis structure" do
      question = %{"text" => "What is 2 + 2?"}
      check_result = %{"is_correct" => false, "student_answer" => "5"}
      
      result = Tools.diagnose_error(question, check_result)
      
      assert is_map(result)
      assert result["error_type"] != nil
      assert result["misconception"] != nil
      assert result["confidence"] != nil
      assert result["recommendations"] != nil
      assert is_list(result["recommendations"])
    end
  end
  
  describe "create_remediation/2" do
    test "creates remediation content" do
      topic = %{id: 1, name: "Addition"}
      diagnosis = %{
        "error_type" => "computational_error",
        "misconception" => "Carried incorrectly"
      }
      
      result = Tools.create_remediation(topic, diagnosis)
      
      assert is_binary(result)
      assert String.contains?(result, diagnosis["error_type"])
      assert String.contains?(result, diagnosis["misconception"])
    end
  end
  
  describe "explain_concept/2" do
    test "generates concept explanation" do
      topic = %{id: 1, name: "Fractions"}
      message = "How do I add fractions?"
      
      result = Tools.explain_concept(topic, message)
      
      assert is_binary(result)
      assert String.contains?(result, message)
      assert String.contains?(result, topic.name)
    end
    
    test "handles nil topic gracefully" do
      message = "What is mathematics?"
      
      result = Tools.explain_concept(nil, message)
      
      assert is_binary(result)
      assert String.contains?(result, message)
      assert String.contains?(result, "this concept")
    end
  end
end