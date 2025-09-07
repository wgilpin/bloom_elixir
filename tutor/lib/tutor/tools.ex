defmodule Tutor.Tools do
  @moduledoc """
  LLM integration tools for tutoring functionality.
  
  These are stub implementations that will be replaced with actual
  LLM API calls in Phase 4 of the implementation plan.
  """

  @doc """
  Generates a question for the given topic.
  Returns {:ok, map} with question data or {:error, reason}.
  """
  def generate_question(topic) do
    # Mock implementation - will be replaced with LLM API call
    {:ok, %{
      "text" => "What is 2 + 2? (This is a mock question for topic: #{inspect(topic)})",
      "topic" => if(is_map(topic), do: topic.name, else: to_string(topic)),
      "type" => "multiple_choice",
      "correct_answer" => "4",
      "options" => ["2", "3", "4", "5"],
      "difficulty" => "basic"
    }}
  end

  @doc """
  Checks if a student's answer is correct.
  Returns {:ok, map} with assessment data or {:error, reason}.
  """
  def check_answer(question, student_answer) do
    # Mock implementation - will be replaced with LLM API call
    is_correct = String.downcase(String.trim(student_answer)) == String.downcase(question["correct_answer"])
    
    {:ok, %{
      "is_correct" => is_correct,
      "feedback" => if is_correct do
        "Excellent! That's correct."
      else
        "Not quite right. Let me help you understand this better."
      end,
      "student_answer" => student_answer,
      "correct_answer" => question["correct_answer"]
    }}
  end

  @doc """
  Diagnoses the type of error made by the student.
  Returns {:ok, map} with error classification or {:error, reason}.
  """
  def diagnose_error(question, answer_data) do
    # Mock implementation - will be replaced with LLM API call
    {:ok, %{
      "error_identified" => true,
      "error_category" => "computational",
      "error_description" => "Basic arithmetic mistake",
      "misconception" => "Confusion with basic addition",
      "confidence" => 0.8,
      "suggested_approach" => "Let's review the basics of addition step by step."
    }}
  end

  @doc """
  Creates targeted remediation for the diagnosed error.
  Returns {:ok, string} with remediation content or {:error, reason}.
  """
  def create_remediation(topic, diagnosis) do
    # Mock implementation - will be replaced with LLM API call
    error_type = diagnosis[:error_type] || diagnosis["error_type"] || "error"
    misconception = diagnosis[:misconception] || diagnosis["misconception"] || "misunderstanding"
    
    {:ok, """
    Let's work on this step by step. 
    
    I see you made a #{error_type}. This often happens due to #{misconception}.
    
    Here's a clearer way to approach this problem:
    1. First, identify what the question is asking
    2. Then, determine which method applies
    3. Finally, work through it systematically
    
    Let's try again with this approach.
    """}
  end

  @doc """
  Explains a concept or answers student questions.
  Returns {:ok, string} with explanation or {:error, reason}.
  """
  def explain_concept(topic, student_message) do
    # Mock implementation - will be replaced with LLM API call
    topic_name = cond do
      is_map(topic) and Map.has_key?(topic, :name) -> topic.name
      is_binary(topic) -> topic
      true -> "this concept"
    end
    
    {:ok, """
    Great question! Let me explain #{topic_name}.
    
    You asked: "#{student_message}"
    
    Here's a helpful way to think about it:
    The key principle here is to break down complex problems into simpler steps.
    Each step should be clear and build on the previous one.
    
    (This is a mock explanation that will be replaced with LLM-generated content)
    """}
  end

  @doc """
  Provides a hint for a question based on context.
  Returns {:ok, string} with the hint or {:error, reason}.
  """
  def provide_hint(question, context_or_prompt) do
    # Mock implementation - will be replaced with LLM API call
    question_text = question["text"] || "the problem"
    
    {:ok, """
    Here's a hint for #{question_text}:
    
    Think about what information you're given and what you need to find.
    Sometimes it helps to work backwards from what you're trying to solve.
    
    Context: #{context_or_prompt}
    
    (This is a mock hint that will be replaced with LLM-generated content)
    """}
  end
end