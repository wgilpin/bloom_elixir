defmodule TutorEx.Learning.AdaptiveIntervention do
  @moduledoc """
  Provides adaptive intervention strategies based on student performance and error patterns.
  
  Uses LLM to generate contextual hints, Socratic questions, and guided dialogue
  for helping students discover correct answers on their own.
  """

  @tools_module Application.compile_env(:tutor, :tools_module, Tutor.Tools)
  
  defp tools_module, do: @tools_module

  @type intervention_level :: :subtle | :moderate | :explicit | :worked_example
  
  @type intervention :: %{
    level: intervention_level(),
    content: String.t(),
    follow_up_question: String.t() | nil,
    next_level: intervention_level() | nil
  }

  @doc """
  Generates an adaptive intervention based on the error diagnosis and attempt number.
  Uses LLM to create contextually appropriate interventions.
  """
  @spec generate_intervention(map(), integer(), map()) :: {:ok, intervention()} | {:error, String.t()}
  def generate_intervention(diagnosis, attempt_number, question) do
    level = determine_intervention_level(attempt_number, diagnosis)
    
    case generate_intervention_content(level, diagnosis, question) do
      {:ok, content} ->
        {:ok, %{
          level: level,
          content: content,
          follow_up_question: generate_follow_up(level, question),
          next_level: get_next_level(level)
        }}
      
      error ->
        error
    end
  end

  @doc """
  Generates a Socratic prompt to guide student thinking using LLM.
  """
  @spec generate_socratic_prompt(map(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_socratic_prompt(question, student_response) do
    prompt = """
    Question: #{question["text"]}
    Student's response: #{student_response}
    Topic: #{question["topic"]}
    
    Generate a Socratic question that will guide the student to think more deeply about their answer.
    The question should:
    1. Not give away the answer
    2. Encourage the student to examine their reasoning
    3. Be appropriate for a GCSE student
    4. Lead them toward discovering their error
    """
    
    tools_module().provide_hint(question, prompt)
  end

  @doc """
  Creates a progressive hint sequence for a question using LLM.
  """
  @spec create_hint_sequence(map()) :: {:ok, [String.t()]} | {:error, String.t()}
  def create_hint_sequence(question) do
    prompt = """
    Question: #{question["text"]}
    Topic: #{question["topic"]}
    
    Create a sequence of 4 progressively more helpful hints:
    1. Subtle hint - just a nudge in the right direction
    2. Moderate hint - clearer guidance without giving the method
    3. Explicit hint - the method/formula to use
    4. Worked example - step-by-step demonstration
    
    Format each hint on a new line, numbered 1-4.
    """
    
    case tools_module().provide_hint(question, prompt) do
      {:ok, response} ->
        hints = response
        |> String.split(~r/\d+\.\s*/)
        |> Enum.filter(&(String.length(&1) > 0))
        |> Enum.map(&String.trim/1)
        {:ok, hints}
      
      error ->
        error
    end
  end

  @doc """
  Generates targeted remediation for known error patterns using LLM.
  """
  @spec generate_known_error_remediation(map(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_known_error_remediation(error_pattern, question) do
    prompt = """
    The student made this specific error: #{error_pattern.description}
    
    Question: #{question["text"]}
    Topic: #{question["topic"]}
    Error category: #{error_pattern.category}
    Remediation strategy: #{error_pattern.remediation_strategy}
    
    Generate a targeted response that:
    1. Acknowledges the specific error
    2. Explains why this is a common mistake
    3. Provides the correct approach
    4. Encourages them to try again
    
    Be supportive and educational.
    """
    
    tools_module().create_remediation(question["topic"], %{
      "error_description" => error_pattern.description,
      "remediation_strategy" => error_pattern.remediation_strategy
    })
  end

  @doc """
  Generates remediation for unknown errors using general strategies and LLM.
  """
  @spec generate_unknown_error_remediation(map(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_unknown_error_remediation(question, student_answer) do
    prompt = """
    Question: #{question["text"]}
    Topic: #{question["topic"]}
    Student's answer: #{student_answer}
    
    The student got this wrong but we don't know the specific error pattern.
    
    Generate a response that:
    1. Acknowledges their attempt
    2. Helps them reflect on their approach
    3. Asks guiding questions to identify where they went wrong
    4. Provides general strategic guidance
    
    Use a Socratic approach to help them discover their error.
    """
    
    tools_module().create_remediation(question["topic"], %{
      "student_answer" => student_answer,
      "error_type" => "unknown",
      "approach" => "socratic_questioning"
    })
  end

  @doc """
  Provides guided dialogue for stuck students using LLM.
  """
  @spec generate_guided_dialogue(map(), String.t(), integer()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_guided_dialogue(question, student_message, dialogue_turn) do
    prompt = """
    This is turn #{dialogue_turn} of a guided dialogue with a struggling GCSE student.
    
    Question they're working on: #{question["text"]}
    Topic: #{question["topic"]}
    Student's last message: #{student_message}
    
    Generate an appropriate response that:
    1. Acknowledges their message
    2. Provides gentle guidance without giving the answer
    3. Asks a follow-up question to keep them engaged
    4. Is encouraging and supportive
    
    #{dialogue_context(dialogue_turn)}
    """
    
    tools_module().provide_hint(question, prompt)
  end

  # Private functions

  defp determine_intervention_level(attempt_number, diagnosis) do
    confidence = diagnosis[:confidence] || 0.0
    
    cond do
      attempt_number == 1 -> :subtle
      attempt_number == 2 and confidence > 0.7 -> :moderate
      attempt_number == 2 -> :subtle
      attempt_number == 3 -> :moderate
      attempt_number == 4 -> :explicit
      attempt_number >= 5 -> :worked_example
      true -> :moderate
    end
  end

  defp generate_intervention_content(level, diagnosis, question) do
    level_description = case level do
      :subtle -> "subtle hint that doesn't give away the method"
      :moderate -> "clearer guidance that suggests the approach"
      :explicit -> "explicit instructions on what method to use"
      :worked_example -> "complete worked example of a similar problem"
    end
    
    prompt = """
    Question: #{question["text"]}
    Topic: #{question["topic"]}
    Error diagnosis: #{diagnosis[:error_description] || "Student is struggling"}
    
    Provide a #{level_description} to help the student.
    The response should be appropriate for a GCSE student.
    #{if diagnosis[:misconception], do: "Address this misconception: #{diagnosis.misconception}", else: ""}
    """
    
    tools_module().provide_hint(question, prompt)
  end

  defp generate_follow_up(:subtle, question) do
    "What do you notice about #{get_question_focus(question)}?"
  end

  defp generate_follow_up(:moderate, question) do
    "Can you identify which step to take first?"
  end

  defp generate_follow_up(:explicit, _question) do
    "Do you understand each step? Which part would you like me to clarify?"
  end

  defp generate_follow_up(:worked_example, _question) do
    nil
  end

  defp get_next_level(:subtle), do: :moderate
  defp get_next_level(:moderate), do: :explicit
  defp get_next_level(:explicit), do: :worked_example
  defp get_next_level(:worked_example), do: nil

  defp dialogue_context(turn) do
    case turn do
      1 -> "This is the first turn - focus on understanding what they find difficult."
      2 -> "Second turn - help them identify the key information in the question."
      3 -> "Third turn - guide them toward the right method or concept."
      4 -> "Fourth turn - help them start applying the method."
      _ -> "Continue supporting them through the problem-solving process."
    end
  end

  defp get_question_focus(question) do
    question["focus"] || "the key values in the problem"
  end
end