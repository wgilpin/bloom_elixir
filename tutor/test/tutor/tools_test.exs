defmodule Tutor.ToolsTest do
  use ExUnit.Case, async: true
  
  alias Tutor.Tools
  
  describe "generate_question/1" do
    test "generates a question with required fields" do
      topic = %{id: 1, name: "Addition"}
      
      assert {:ok, result} = Tools.generate_question(topic)
      assert is_map(result)
      assert result["text"] != nil
      assert result["type"] != nil
      assert result["correct_answer"] != nil
      assert result["options"] != nil
      assert result["difficulty"] != nil
      assert result["topic"] == topic.name
    end
    
    test "handles string topic" do
      topic = "Algebra"
      
      assert {:ok, result} = Tools.generate_question(topic)
      assert is_map(result)
      assert result["topic"] == topic
    end
  end
  
  describe "check_answer/2" do
    test "correctly identifies correct answer" do
      question = %{"correct_answer" => "4"}
      
      assert {:ok, result} = Tools.check_answer(question, "4")
      assert result["is_correct"] == true
      assert result["feedback"] != nil
      assert String.contains?(result["feedback"], "correct")
      assert result["student_answer"] == "4"
      assert result["correct_answer"] == "4"
    end
    
    test "correctly identifies incorrect answer" do
      question = %{"correct_answer" => "4"}
      
      assert {:ok, result} = Tools.check_answer(question, "5")
      assert result["is_correct"] == false
      assert result["feedback"] != nil
      assert String.contains?(result["feedback"], "Not quite")
    end
    
    test "handles case-insensitive answers" do
      question = %{"correct_answer" => "Paris"}
      
      assert {:ok, result} = Tools.check_answer(question, "paris")
      assert result["is_correct"] == true
    end
    
    test "handles whitespace in answers" do
      question = %{"correct_answer" => "4"}
      
      assert {:ok, result} = Tools.check_answer(question, "  4  ")
      assert result["is_correct"] == true
    end
  end
  
  describe "diagnose_error/2" do
    test "returns error diagnosis structure" do
      question = %{"text" => "What is 2 + 2?"}
      answer_data = %{
        "student_answer" => "5",
        "correct_answer" => "4",
        "is_correct" => false
      }
      
      assert {:ok, result} = Tools.diagnose_error(question, answer_data)
      assert is_map(result)
      assert result["error_identified"] != nil
      assert result["error_category"] != nil
      assert result["error_description"] != nil
      assert result["misconception"] != nil
      assert result["confidence"] != nil
      assert result["suggested_approach"] != nil
    end
  end
  
  describe "create_remediation/2" do
    test "creates remediation content" do
      topic = "Addition"
      diagnosis = %{
        "error_type" => "computational_error",
        "misconception" => "Carried incorrectly"
      }
      
      assert {:ok, result} = Tools.create_remediation(topic, diagnosis)
      assert is_binary(result)
      assert String.contains?(result, diagnosis["error_type"])
      assert String.contains?(result, diagnosis["misconception"])
    end
    
    test "handles atom keys in diagnosis" do
      topic = "Fractions"
      diagnosis = %{
        error_type: "fraction_error",
        misconception: "Added denominators"
      }
      
      assert {:ok, result} = Tools.create_remediation(topic, diagnosis)
      assert is_binary(result)
      assert String.contains?(result, "fraction_error")
    end
  end
  
  describe "explain_concept/2" do
    test "generates concept explanation" do
      topic = %{id: 1, name: "Fractions"}
      message = "How do I add fractions?"
      
      assert {:ok, result} = Tools.explain_concept(topic, message)
      assert is_binary(result)
      assert String.contains?(result, message)
      assert String.contains?(result, topic.name)
    end
    
    test "handles string topic" do
      topic = "Algebra"
      message = "What are variables?"
      
      assert {:ok, result} = Tools.explain_concept(topic, message)
      assert is_binary(result)
      assert String.contains?(result, message)
      assert String.contains?(result, topic)
    end
    
    test "handles nil topic gracefully" do
      message = "What is mathematics?"
      
      assert {:ok, result} = Tools.explain_concept(nil, message)
      assert is_binary(result)
      assert String.contains?(result, message)
      assert String.contains?(result, "this concept")
    end
  end
  
  describe "provide_hint/2" do
    test "provides hint for question" do
      question = %{"text" => "Solve for x: 2x + 5 = 13", "topic" => "algebra"}
      context = "Student is struggling with isolation"
      
      assert {:ok, result} = Tools.provide_hint(question, context)
      assert is_binary(result)
      assert String.contains?(result, context)
    end
    
    test "handles question without text field" do
      question = %{"topic" => "geometry"}
      context = "Help with angles"
      
      assert {:ok, result} = Tools.provide_hint(question, context)
      assert is_binary(result)
      assert String.contains?(result, "the problem")
    end
  end
end