defmodule Tutor.Tools do
  @moduledoc """
  LLM integration tools for tutoring functionality.

  Provides real-time AI tutoring capabilities through configurable LLM providers.
  Supports OpenAI, Google Gemini, xAI Grok, and other providers.
  All functions are async and designed to be used with Task.Supervisor.
  """

  require Logger
  alias Tutor.LLM.Client

  # System prompts for different tutoring functions
  @system_prompts %{
    check_answer: """
    You are an expert GCSE Mathematics tutor. You need to check if a student's answer is correct.

    Analyze the student's response carefully and return a JSON object with:
    - "is_correct": boolean indicating if the answer is correct
    - "feedback": encouraging feedback appropriate for the correctness
    - "explanation": brief explanation of why the answer is correct/incorrect
    - "student_answer": the student's original answer
    - "correct_answer": the correct answer

    Be encouraging and constructive in your feedback. For correct answers, provide positive reinforcement.
    For incorrect answers, be gentle but clear about what went wrong.
    """,

    generate_question: """
    You are an expert GCSE Mathematics tutor. Generate an appropriate practice question.

    Create a question that:
    - Is appropriate for GCSE level (ages 14-16)
    - Matches the given topic and difficulty
    - Has clear, unambiguous wording
    - Can be answered definitively

    Return a JSON object with:
    - "text": the question text
    - "topic": the topic name
    - "type": question type ("open_ended", "multiple_choice", etc.)
    - "correct_answer": the correct answer
    - "difficulty": "foundation", "higher", or "advanced"
    - "hint": optional hint if the question is complex
    """,

    diagnose_error: """
    You are an expert GCSE Mathematics tutor specializing in error diagnosis.

    Analyze the student's incorrect answer to identify:
    - The specific type of error made
    - Whether it's a simple slip, procedural bug, or deeper misconception
    - The likely cause of the error

    Return a JSON object with:
    - "error_identified": boolean if an error pattern was found
    - "error_category": "computational", "conceptual", "procedural", or "misreading"
    - "error_description": specific description of what went wrong
    - "misconception": underlying misconception if present
    - "confidence": confidence level (0.0-1.0)
    - "suggested_approach": brief suggestion for addressing this error
    """,

    create_remediation: """
    You are an expert GCSE Mathematics tutor creating personalized remediation.

    Based on the error diagnosis, create targeted instruction to help the student understand their mistake.
    Use pedagogical techniques like:
    - Visual models and concrete examples
    - Step-by-step breakdowns
    - Cognitive conflict (showing why their approach doesn't work)
    - Building from their current understanding

    Provide clear, encouraging remediation that addresses the root cause of the error.
    Keep it concise but thorough enough to create understanding.
    """,

    explain_concept: """
    You are an expert GCSE Mathematics tutor providing concept explanations.

    Explain the concept clearly and appropriately for GCSE level (ages 14-16):
    - Use clear, accessible language
    - Provide concrete examples
    - Connect to prior knowledge where possible
    - Break down complex ideas into simpler components

    Tailor your explanation to the student's specific question or context.
    Be encouraging and build confidence while being mathematically accurate.
    """
  }

  @doc """
  Generates a question for the given topic using AI.
  Returns {:ok, map} with question data or {:error, reason}.
  """
  def generate_question(topic, conversation_history \\ []) do
    topic_name = cond do
      is_map(topic) and Map.has_key?(topic, :name) -> topic.name
      is_map(topic) and Map.has_key?(topic, "name") -> topic["name"]
      is_binary(topic) -> topic
      true -> "General Mathematics"
    end

    difficulty = cond do
      is_map(topic) and Map.has_key?(topic, :difficulty) -> topic.difficulty
      is_map(topic) and Map.has_key?(topic, "difficulty") -> topic["difficulty"]
      true -> "foundation"
    end

    # Build conversation context
    context = if Enum.empty?(conversation_history) do
      ""
    else
      recent_messages = conversation_history
        |> Enum.take(-6)  # Last 6 messages
        |> Enum.reverse()
        |> Enum.map(fn entry ->
          role_name = case entry.role do
            :user -> "Student"
            :system -> "AI Tutor"
            _ -> "System"
          end
          "#{role_name}: #{entry.content}"
        end)
        |> Enum.join("\n")

      """

      Recent conversation context:
      #{recent_messages}

      Based on this conversation, the student is requesting another question.
      """
    end

    prompt = """
    Generate a GCSE Mathematics question for the topic: #{topic_name}
    Difficulty level: #{difficulty}#{context}

    Please respond with valid JSON only.
    """

    case make_api_request(@system_prompts.generate_question, prompt, %{}, :generate_question) do
      {:ok, response} ->
        case Jason.decode(response) do
          {:ok, data} -> {:ok, data}
          {:error, _} ->
            Logger.warning("Failed to parse LLM response for generate_question, using fallback")
            generate_fallback_question(topic_name, difficulty)
        end
      {:error, reason} ->
        Logger.warning("API request failed for generate_question: #{inspect(reason)}, using fallback")
        generate_fallback_question(topic_name, difficulty)
    end
  end

  # Fallback question generation
  defp generate_fallback_question(topic_name, difficulty) do
    {:ok, %{
      "text" => "Solve this problem related to #{topic_name}. What is 7 + 8?",
      "topic" => topic_name,
      "type" => "open_ended",
      "correct_answer" => "15",
      "difficulty" => difficulty,
      "hint" => "Add the two numbers together."
    }}
  end

  @doc """
  Checks if a student's answer is correct using AI analysis.
  Returns {:ok, map} with assessment data or {:error, reason}.
  """
  def check_answer(question, student_answer) do
    prompt = """
    Question: #{question["text"] || "Unknown question"}
    Expected Answer: #{question["correct_answer"] || "Unknown"}
    Student Answer: #{student_answer}

    Please analyze this answer and respond with valid JSON only.
    """

    case make_api_request(@system_prompts.check_answer, prompt, %{}, :check_answer) do
      {:ok, response} ->
        case Jason.decode(response) do
          {:ok, data} -> {:ok, data}
          {:error, _} ->
            # Fallback to simple comparison if JSON parsing fails
            Logger.warning("Failed to parse LLM response for check_answer, using fallback")
            simple_check_answer(question, student_answer)
        end
      {:error, reason} ->
        Logger.warning("API request failed for check_answer: #{inspect(reason)}, using fallback")
        simple_check_answer(question, student_answer)
    end
  end

  # Fallback implementation for when API fails
  defp simple_check_answer(question, student_answer) do
    is_correct = String.downcase(String.trim(student_answer)) ==
                 String.downcase(String.trim(question["correct_answer"] || ""))

    {:ok, %{
      "is_correct" => is_correct,
      "feedback" => if is_correct do
        "Excellent! That's correct."
      else
        "Not quite right. Let me help you understand this better."
      end,
      "explanation" => "Basic comparison check (fallback mode)",
      "student_answer" => student_answer,
      "correct_answer" => question["correct_answer"]
    }}
  end

  @doc """
  Diagnoses the type of error made by the student using AI analysis.
  Returns {:ok, map} with error classification or {:error, reason}.
  """
  def diagnose_error(question, answer_data) do
    question_text = question["text"] || "Unknown question"
    correct_answer = question["correct_answer"] || "Unknown"
    student_answer = answer_data["student_answer"] || "No answer provided"

    prompt = """
    Question: #{question_text}
    Correct Answer: #{correct_answer}
    Student Answer: #{student_answer}

    Analyze this incorrect answer to identify the error pattern and underlying misconception.
    Please respond with valid JSON only.
    """

    case make_api_request(@system_prompts.diagnose_error, prompt, %{}, :diagnose_error) do
      {:ok, response} ->
        case Jason.decode(response) do
          {:ok, data} -> {:ok, data}
          {:error, _} ->
            Logger.warning("Failed to parse LLM response for diagnose_error, using fallback. #{response}")
            diagnose_fallback_error(question, answer_data)
        end
      {:error, reason} ->
        Logger.warning("API request failed for diagnose_error: #{inspect(reason)}, using fallback")
        diagnose_fallback_error(question, answer_data)
    end
  end

  # Fallback error diagnosis
  defp diagnose_fallback_error(_question, _answer_data) do
    {:ok, %{
      "error_identified" => true,
      "error_category" => "computational",
      "error_description" => "Answer does not match expected result",
      "misconception" => "Possible procedural error or misunderstanding",
      "confidence" => 0.6,
      "suggested_approach" => "Let's work through this step by step to identify where the confusion occurred."
    }}
  end

  @doc """
  Creates targeted remediation for the diagnosed error using AI.
  Returns {:ok, string} with remediation content or {:error, reason}.
  """
  def create_remediation(topic, diagnosis) do
    topic_name = cond do
      is_map(topic) and Map.has_key?(topic, :name) -> topic.name
      is_map(topic) and Map.has_key?(topic, "name") -> topic["name"]
      is_binary(topic) -> topic
      true -> "this concept"
    end

    error_category = diagnosis["error_category"] || "general error"
    error_description = diagnosis["error_description"] || "mistake in reasoning"
    misconception = diagnosis["misconception"] || "misunderstanding"

    prompt = """
    Topic: #{topic_name}
    Error Category: #{error_category}
    Error Description: #{error_description}
    Underlying Misconception: #{misconception}

    Create targeted remediation to help the student understand and correct this error.
    Focus on the root cause and provide clear, step-by-step guidance.
    """

    case make_api_request(@system_prompts.create_remediation, prompt, %{}, :create_remediation) do
      {:ok, response} -> {:ok, response}
      {:error, reason} ->
        Logger.warning("API request failed for create_remediation: #{inspect(reason)}, using fallback")
        create_fallback_remediation(error_category, misconception)
    end
  end

  # Fallback remediation creation
  defp create_fallback_remediation(error_category, misconception) do
    {:ok, """
    Let's work on this step by step.

    I see you made a #{error_category}. This often happens due to #{misconception}.

    Here's a clearer way to approach this problem:
    1. First, identify what the question is asking
    2. Then, determine which method or formula applies
    3. Work through it systematically, checking each step
    4. Verify your answer makes sense in context

    Let's try again with this approach. Take your time and think through each step.
    """}
  end

  @doc """
  Explains a concept or answers student questions using AI.
  Returns {:ok, string} with explanation or {:error, reason}.
  """
  def explain_concept(topic, student_message, conversation_history \\ []) do
    topic_name = cond do
      is_map(topic) and Map.has_key?(topic, :name) -> topic.name
      is_map(topic) and Map.has_key?(topic, "name") -> topic["name"]
      is_binary(topic) -> topic
      true -> "this concept"
    end

    # Build conversation context
    context = if Enum.empty?(conversation_history) do
      ""
    else
      recent_messages = conversation_history
        |> Enum.take(-6)  # Last 6 messages
        |> Enum.reverse()
        |> Enum.map(fn entry ->
          role_name = case entry.role do
            :user -> "Student"
            :system -> "AI Tutor"
            _ -> "System"
          end
          "#{role_name}: #{entry.content}"
        end)
        |> Enum.join("\n")

      """

      Recent conversation context:
      #{recent_messages}

      """
    end

    prompt = """
    Topic: #{topic_name}
    Student Question: "#{student_message}"#{context}

    Please explain this concept clearly for a GCSE student.
    Address their specific question and provide a helpful, encouraging explanation.
    If the student is asking for "another" question or similar, generate an appropriate question.
    """

    case make_api_request(@system_prompts.explain_concept, prompt, %{}, :explain_concept) do
      {:ok, response} -> {:ok, response}
      {:error, reason} ->
        Logger.warning("API request failed for explain_concept: #{inspect(reason)}, using fallback")
        explain_fallback_concept(topic_name, student_message)
    end
  end

  # Fallback concept explanation
  defp explain_fallback_concept(topic_name, student_message) do
    {:ok, """
    Great question! Let me explain #{topic_name}.

    You asked: "#{student_message}"

    Here's a helpful way to think about it:
    The key principle here is to break down complex problems into simpler steps.
    Each step should be clear and build on the previous one.

    When working with #{topic_name}, it's important to:
    1. Understand what you're being asked to find
    2. Identify what information you have
    3. Choose the right method or formula
    4. Work through the solution step by step
    5. Check that your answer makes sense

    Would you like me to work through a specific example with you?
    """}
  end

  @doc """
  Classifies user intent from their message.
  Returns {:ok, intent} where intent is one of:
    - :request_question - User wants a practice question
    - :request_help - User wants help or explanation
    - :understanding_confirmation - User indicates they understand
    - :confusion - User indicates confusion or lack of understanding
    - :answer_attempt - User is providing an answer to a question
    - :general - General conversation
  """
  def classify_intent(message, conversation_history \\ []) do
    # Build conversation context
    context = if Enum.empty?(conversation_history) do
      ""
    else
      recent_messages = conversation_history
        |> Enum.take(-4)  # Last 4 messages for context
        |> Enum.reverse()
        |> Enum.map(fn entry ->
          role_name = case entry.role do
            :user -> "Student"
            :system -> "AI Tutor"
            _ -> "System"
          end
          "#{role_name}: #{entry.content}"
        end)
        |> Enum.join("\n")

      """

      Recent conversation context:
      #{recent_messages}

      """
    end

    system_prompt = """
    You are an intent classifier for an AI tutoring system. Analyze the student's message and classify their intent.

    Return ONLY one of these exact words:
    - "request_question" if they want a practice question/problem (e.g., "give me another", "next question", "more problems")
    - "request_help" if they want help/explanation (e.g., "explain this", "I don't understand", "help me")
    - "understanding_confirmation" if they indicate understanding (e.g., "I get it", "makes sense", "oh I see", "got it")
    - "confusion" if they express confusion or lack of understanding (e.g., "I'm confused", "this doesn't make sense", "I don't get it")
    - "answer_attempt" if they're providing an answer to a math problem (contains numbers, equations, or mathematical expressions)
    - "general" for general conversation or other intents

    Be generous in interpretation. Look for the primary intent even if phrased casually.
    """

    prompt = """
    Student message: "#{message}"#{context}

    Intent:
    """

    case make_api_request(system_prompt, prompt, %{}, :classify_intent) do
      {:ok, response} ->
        intent = response |> String.trim() |> String.downcase()
        case intent do
          "request_question" -> {:ok, :request_question}
          "request_help" -> {:ok, :request_help}
          "understanding_confirmation" -> {:ok, :understanding_confirmation}
          "confusion" -> {:ok, :confusion}
          "answer_attempt" -> {:ok, :answer_attempt}
          "general" -> {:ok, :general}
          _ -> {:ok, :general} # Default fallback
        end
      {:error, _reason} ->
        # Fallback to simple keyword matching if LLM fails
        message_lower = String.downcase(message)
        cond do
          # Question requests
          String.contains?(message_lower, "another") or
          String.contains?(message_lower, "more") or
          String.contains?(message_lower, "next") or
          String.contains?(message_lower, "question") ->
            {:ok, :request_question}

          # Help requests
          String.contains?(message_lower, "help") or
          String.contains?(message_lower, "explain") or
          String.contains?(message_lower, "don't understand") ->
            {:ok, :request_help}

          # Understanding confirmations
          String.contains?(message_lower, "got it") or
          String.contains?(message_lower, "makes sense") or
          String.contains?(message_lower, "i see") or
          String.contains?(message_lower, "understand") ->
            {:ok, :understanding_confirmation}

          # Confusion indicators
          String.contains?(message_lower, "confused") or
          String.contains?(message_lower, "don't get") or
          String.contains?(message_lower, "lost") ->
            {:ok, :confusion}

          # Answer attempts (contains numbers)
          Regex.match?(~r/\d+/, message) ->
            {:ok, :answer_attempt}

          true ->
            {:ok, :general}
        end
    end
  end

  @doc """
  Provides a hint for a question based on context.
  Returns {:ok, string} with the hint or {:error, reason}.
  """
  def provide_hint(question, context_or_prompt) do
    question_text = question["text"] || "the problem"

    prompt = """
    Question: #{question_text}
    Context: #{context_or_prompt}

    Provide a helpful hint that guides the student toward the solution without giving the answer away.
    The hint should be encouraging and help them think through the problem.
    """

    system_prompt = """
    You are an expert GCSE Mathematics tutor providing hints.

    Give a helpful hint that:
    - Doesn't give away the answer
    - Guides the student's thinking in the right direction
    - Is encouraging and supportive
    - Helps them identify the key insight or method needed

    Keep the hint concise but helpful.
    """

    case make_api_request(system_prompt, prompt, %{}, :provide_hint) do
      {:ok, response} -> {:ok, response}
      {:error, reason} ->
        Logger.warning("API request failed for provide_hint: #{inspect(reason)}, using fallback")
        provide_fallback_hint(question_text, context_or_prompt)
    end
  end

  # Fallback hint provision
  defp provide_fallback_hint(question_text, context_or_prompt) do
    {:ok, """
    Here's a hint for #{question_text}:

    Think about what information you're given and what you need to find.
    Sometimes it helps to work backwards from what you're trying to solve.

    Context: #{context_or_prompt}

    Try breaking the problem down into smaller steps, and tackle each one at a time.
    """}
  end

  # Private function to make API requests through the LLM client
  defp make_api_request(system_prompt, user_prompt, opts \\ %{}) do
    make_api_request_with_context(system_prompt, user_prompt, opts, :unknown_tool)
  end
  
  defp make_api_request(system_prompt, user_prompt, opts, tool_name) do
    make_api_request_with_context(system_prompt, user_prompt, opts, tool_name)
  end
  
  defp make_api_request_with_context(system_prompt, user_prompt, opts, tool_name) do
    # Get logging configuration (returns keyword list)
    llm_logging = Application.get_env(:tutor, :llm_logging, [])
    enabled = Keyword.get(llm_logging, :enabled, true)
    
    if enabled do
      Logger.info("🛠️ Tool Call: #{tool_name}")
      Logger.debug("🛠️ Tool System Prompt: #{inspect(system_prompt, limit: 500)}")
      Logger.debug("🛠️ Tool User Prompt: #{inspect(user_prompt, limit: 1000)}")
    end
    
    messages = [
      Client.format_message("system", system_prompt),
      Client.format_message("user", user_prompt)
    ]

    default_opts = %{
      temperature: 0.7,
      max_tokens: 1000
    }

    start_time = System.monotonic_time()
    result = Client.chat_completion(messages, Map.merge(default_opts, opts))
    end_time = System.monotonic_time()
    duration_ms = System.convert_time_unit(end_time - start_time, :native, :millisecond)
    
    if enabled do
      case result do
        {:ok, response} ->
          Logger.info("🛠️ Tool Result: #{tool_name} completed in #{duration_ms}ms")
          Logger.debug("🛠️ Tool Response: #{inspect(response, limit: 1000)}")
        {:error, reason} ->
          Logger.error("🛠️ Tool Error: #{tool_name} failed in #{duration_ms}ms - #{inspect(reason)}")
      end
    end
    
    result
  end
end
