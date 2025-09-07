defmodule TutorEx.Learning.ErrorDiagnosisEngine do
  @moduledoc """
  Engine for diagnosing student errors and misconceptions in mathematics.
  
  Uses LLM to intelligently analyze student answers, identify error patterns,
  and provide targeted remediation strategies.
  """

  @tools_module Application.compile_env(:tutor, :tools_module, Tutor.Tools)
  
  defp tools_module, do: @tools_module

  @type diagnosis :: %{
    error_type: :known | :unknown,
    error_category: String.t() | nil,
    error_description: String.t(),
    confidence: float(),
    misconception: String.t() | nil,
    suggested_remediation: String.t()
  }

  @doc """
  Diagnoses an error by using LLM to analyze the student's answer.
  This is typically called asynchronously via Task.
  """
  @spec diagnose_error(map(), map(), String.t()) :: {:ok, diagnosis()} | {:error, String.t()}
  def diagnose_error(question, check_result, student_answer) do
    # Use LLM to analyze the error
    case tools_module().diagnose_error(question, %{
      student_answer: student_answer,
      correct_answer: check_result["correct_answer"],
      is_correct: check_result["is_correct"]
    }) do
      {:ok, llm_diagnosis} ->
        {:ok, parse_llm_diagnosis(llm_diagnosis)}
      
      {:error, reason} ->
        # Fallback to a generic diagnosis if LLM fails
        {:ok, %{
          error_type: :unknown,
          error_category: nil,
          error_description: "Unable to determine specific error",
          confidence: 0.0,
          misconception: nil,
          suggested_remediation: "Let's work through this problem step by step."
        }}
    end
  end

  @doc """
  Requests LLM to identify common misconceptions for a given topic.
  Used for proactive error prevention during instruction.
  """
  @spec get_common_misconceptions(String.t()) :: {:ok, list()} | {:error, String.t()}
  def get_common_misconceptions(topic) do
    prompt = """
    List the most common misconceptions and errors that GCSE students make when learning about #{topic}.
    For each misconception, provide:
    1. A brief description
    2. Why students make this error
    3. How to correct it
    
    Format as a list of structured points.
    """
    
    case tools_module().explain_concept(topic, prompt) do
      {:ok, response} ->
        {:ok, parse_misconceptions(response)}
      error ->
        error
    end
  end

  @doc """
  Generates a targeted remediation strategy using LLM based on the diagnosis.
  """
  @spec generate_targeted_remediation(diagnosis(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_targeted_remediation(diagnosis, question) do
    tools_module().create_remediation(
      question["topic"],
      %{
        question: question["text"],
        error_type: diagnosis.error_type,
        error_description: diagnosis.error_description,
        misconception: diagnosis.misconception,
        student_level: question["difficulty"] || "foundation"
      }
    )
  end

  @doc """
  Generates a hint for a question using LLM.
  """
  @spec generate_hint(map(), String.t() | nil) :: {:ok, String.t()} | {:error, String.t()}
  def generate_hint(question, student_attempt \\ nil) do
    context = if student_attempt do
      "The student attempted: #{student_attempt}"
    else
      "The student hasn't attempted an answer yet."
    end
    
    prompt = """
    Question: #{question["text"]}
    Topic: #{question["topic"]}
    #{context}
    
    Provide a helpful hint that guides the student toward the solution without giving away the answer.
    The hint should be appropriate for a GCSE student.
    """
    
    tools_module().provide_hint(question, prompt)
  end

  @doc """
  Generates a worked example using LLM.
  """
  @spec generate_worked_example(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_worked_example(topic, error_type) do
    prompt = """
    Create a worked example for a GCSE #{topic} problem.
    Focus on addressing this type of error: #{error_type}
    
    The example should:
    1. Present a similar problem
    2. Show step-by-step solution
    3. Highlight where students commonly go wrong
    4. Explain the correct approach
    """
    
    tools_module().explain_concept(topic, prompt)
  end

  # Private helper functions

  defp parse_llm_diagnosis(llm_response) when is_map(llm_response) do
    %{
      error_type: if(llm_response["error_identified"], do: :known, else: :unknown),
      error_category: llm_response["error_category"],
      error_description: llm_response["error_description"] || "Error analysis in progress",
      confidence: parse_confidence(llm_response["confidence"]),
      misconception: llm_response["misconception"],
      suggested_remediation: llm_response["suggested_approach"] || "Let's work through this together"
    }
  end

  defp parse_llm_diagnosis(_), do: default_diagnosis()

  defp parse_confidence(nil), do: 0.5
  defp parse_confidence(conf) when is_float(conf), do: conf
  defp parse_confidence(conf) when is_binary(conf) do
    case Float.parse(conf) do
      {value, _} -> min(1.0, max(0.0, value))
      :error -> 0.5
    end
  end
  defp parse_confidence(_), do: 0.5

  defp parse_misconceptions(response) when is_binary(response) do
    # Simple parsing - in production, could use more sophisticated NLP
    response
    |> String.split("\n")
    |> Enum.filter(&(String.length(&1) > 0))
    |> Enum.map(&String.trim/1)
  end
  defp parse_misconceptions(_), do: []

  defp default_diagnosis do
    %{
      error_type: :unknown,
      error_category: nil,
      error_description: "Unable to determine specific error",
      confidence: 0.0,
      misconception: nil,
      suggested_remediation: "Let's review the problem step by step."
    }
  end
end