defmodule Tutor.ToolsTest do
  use ExUnit.Case, async: false
  
  import Mock
  
  alias Tutor.Tools
  
  setup do
    # Store original environment variable
    original_api_key = System.get_env("OPENAI_API_KEY")
    
    # Set a test API key for testing
    System.put_env("OPENAI_API_KEY", "test-api-key")
    
    on_exit(fn ->
      # Restore original environment variable
      if original_api_key do
        System.put_env("OPENAI_API_KEY", original_api_key)
      else
        System.delete_env("OPENAI_API_KEY")
      end
    end)
    
    :ok
  end

  describe "generate_question/1" do
    test "generates a question with successful API response" do
      topic = %{name: "Addition", difficulty: "foundation"}
      
      # Mock successful API response
      api_response = %{
        status: 200,
        body: %{
          "choices" => [
            %{
              "message" => %{
                "content" => Jason.encode!(%{
                  "text" => "What is 7 + 5?",
                  "topic" => "Addition",
                  "type" => "open_ended",
                  "correct_answer" => "12",
                  "difficulty" => "foundation",
                  "hint" => "Add the two numbers together."
                })
              }
            }
          ]
        }
      }
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:ok, api_response} end]) do
        assert {:ok, result} = Tools.generate_question(topic)
        assert is_map(result)
        assert result["text"] == "What is 7 + 5?"
        assert result["topic"] == "Addition"
        assert result["type"] == "open_ended"
        assert result["correct_answer"] == "12"
        assert result["difficulty"] == "foundation"
      end
    end
    
    test "falls back gracefully when API fails" do
      topic = %{name: "Algebra", difficulty: "higher"}
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:error, :timeout} end]) do
        assert {:ok, result} = Tools.generate_question(topic)
        assert is_map(result)
        assert result["topic"] == "Algebra"
        assert result["difficulty"] == "higher"
        assert String.contains?(result["text"], "Algebra")
      end
    end
    
    test "handles string topic" do
      topic = "Geometry"
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:error, :network_error} end]) do
        assert {:ok, result} = Tools.generate_question(topic)
        assert is_map(result)
        assert result["topic"] == "Geometry"
        assert result["difficulty"] == "foundation"  # default
      end
    end
    
    test "handles invalid JSON response gracefully" do
      topic = "Statistics"
      
      api_response = %{
        status: 200,
        body: %{
          "choices" => [
            %{
              "message" => %{
                "content" => "invalid json content"
              }
            }
          ]
        }
      }
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:ok, api_response} end]) do
        assert {:ok, result} = Tools.generate_question(topic)
        assert is_map(result)
        assert String.contains?(result["text"], "Statistics")
      end
    end
  end

  describe "check_answer/2" do
    test "correctly analyzes answer with successful API response" do
      question = %{"text" => "What is 3 + 5?", "correct_answer" => "8"}
      student_answer = "8"
      
      api_response = %{
        status: 200,
        body: %{
          "choices" => [
            %{
              "message" => %{
                "content" => Jason.encode!(%{
                  "is_correct" => true,
                  "feedback" => "Excellent! That's exactly right.",
                  "explanation" => "You correctly added 3 and 5 to get 8.",
                  "student_answer" => "8",
                  "correct_answer" => "8"
                })
              }
            }
          ]
        }
      }
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:ok, api_response} end]) do
        assert {:ok, result} = Tools.check_answer(question, student_answer)
        assert result["is_correct"] == true
        assert result["feedback"] == "Excellent! That's exactly right."
        assert result["explanation"] == "You correctly added 3 and 5 to get 8."
        assert result["student_answer"] == "8"
        assert result["correct_answer"] == "8"
      end
    end
    
    test "identifies incorrect answer with AI analysis" do
      question = %{"text" => "What is 7 × 8?", "correct_answer" => "56"}
      student_answer = "54"
      
      api_response = %{
        status: 200,
        body: %{
          "choices" => [
            %{
              "message" => %{
                "content" => Jason.encode!(%{
                  "is_correct" => false,
                  "feedback" => "Not quite right. You're very close though!",
                  "explanation" => "The answer should be 56, not 54. This looks like a small computational error.",
                  "student_answer" => "54",
                  "correct_answer" => "56"
                })
              }
            }
          ]
        }
      }
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:ok, api_response} end]) do
        assert {:ok, result} = Tools.check_answer(question, student_answer)
        assert result["is_correct"] == false
        assert String.contains?(result["feedback"], "Not quite right")
        assert result["student_answer"] == "54"
        assert result["correct_answer"] == "56"
      end
    end
    
    test "falls back to simple comparison when API fails" do
      question = %{"correct_answer" => "12"}
      student_answer = "12"
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:error, :timeout} end]) do
        assert {:ok, result} = Tools.check_answer(question, student_answer)
        assert result["is_correct"] == true
        assert String.contains?(result["feedback"], "correct")
        assert result["student_answer"] == "12"
        assert result["correct_answer"] == "12"
      end
    end
    
    test "fallback handles case-insensitive comparison" do
      question = %{"correct_answer" => "Paris"}
      student_answer = "PARIS"
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:error, :network_error} end]) do
        assert {:ok, result} = Tools.check_answer(question, student_answer)
        assert result["is_correct"] == true
      end
    end
    
    test "handles missing API key gracefully" do
      question = %{"text" => "Test question", "correct_answer" => "42"}
      student_answer = "42"
      
      # Temporarily remove API key
      System.delete_env("OPENAI_API_KEY")
      
      assert {:ok, result} = Tools.check_answer(question, student_answer)
      assert result["is_correct"] == true
      assert String.contains?(result["explanation"], "fallback mode")
      
      # Restore API key
      System.put_env("OPENAI_API_KEY", "test-api-key")
    end
  end

  describe "diagnose_error/2" do
    test "diagnoses error with successful API response" do
      question = %{"text" => "What is 15 ÷ 3?", "correct_answer" => "5"}
      answer_data = %{
        "student_answer" => "6",
        "correct_answer" => "5",
        "is_correct" => false
      }
      
      api_response = %{
        status: 200,
        body: %{
          "choices" => [
            %{
              "message" => %{
                "content" => Jason.encode!(%{
                  "error_identified" => true,
                  "error_category" => "computational",
                  "error_description" => "Confusion between addition and division",
                  "misconception" => "Student may have added 3 to 15 instead of dividing",
                  "confidence" => 0.85,
                  "suggested_approach" => "Review division concept with concrete examples"
                })
              }
            }
          ]
        }
      }
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:ok, api_response} end]) do
        assert {:ok, result} = Tools.diagnose_error(question, answer_data)
        assert result["error_identified"] == true
        assert result["error_category"] == "computational"
        assert String.contains?(result["error_description"], "addition and division")
        assert result["confidence"] == 0.85
      end
    end
    
    test "provides fallback diagnosis when API fails" do
      question = %{"text" => "Solve: 2x = 10"}
      answer_data = %{
        "student_answer" => "x = 20",
        "correct_answer" => "x = 5",
        "is_correct" => false
      }
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:error, :api_error} end]) do
        assert {:ok, result} = Tools.diagnose_error(question, answer_data)
        assert is_map(result)
        assert result["error_identified"] == true
        assert result["error_category"] == "computational"
        assert result["confidence"] == 0.6
        assert String.contains?(result["suggested_approach"], "step by step")
      end
    end
    
    test "handles invalid JSON response in diagnosis" do
      question = %{"text" => "What is 50% of 80?"}
      answer_data = %{"student_answer" => "30", "correct_answer" => "40"}
      
      api_response = %{
        status: 200,
        body: %{
          "choices" => [
            %{
              "message" => %{
                "content" => "This is not valid JSON"
              }
            }
          ]
        }
      }
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:ok, api_response} end]) do
        assert {:ok, result} = Tools.diagnose_error(question, answer_data)
        assert result["error_identified"] == true
        assert result["error_category"] == "computational"
      end
    end
  end

  describe "create_remediation/2" do
    test "creates targeted remediation with successful API response" do
      topic = %{"name" => "Fractions"}
      diagnosis = %{
        "error_category" => "conceptual",
        "error_description" => "Added numerators and denominators separately",
        "misconception" => "Treats fractions like separate whole numbers"
      }
      
      remediation_text = """
      I can see you're thinking of fractions as two separate numbers to work with. Let's clarify this concept.
      
      When adding fractions, we need a common denominator first. Here's why:
      
      Think of fractions as pieces of pie. If you have 1/4 of a pie and 1/3 of a pie, you can't just add the tops and bottoms separately because they're different sized pieces.
      
      Let's practice step by step:
      1. Find a common denominator
      2. Convert both fractions 
      3. Add only the numerators
      4. Keep the common denominator
      """
      
      api_response = %{
        status: 200,
        body: %{
          "choices" => [
            %{
              "message" => %{
                "content" => remediation_text
              }
            }
          ]
        }
      }
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:ok, api_response} end]) do
        assert {:ok, result} = Tools.create_remediation(topic, diagnosis)
        assert is_binary(result)
        assert String.contains?(result, "common denominator")
        assert String.contains?(result, "step by step")
      end
    end
    
    test "provides fallback remediation when API fails" do
      topic = "Algebra"
      diagnosis = %{
        "error_category" => "procedural",
        "error_description" => "Incorrect variable isolation",
        "misconception" => "Applied operations to wrong side"
      }
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:error, :timeout} end]) do
        assert {:ok, result} = Tools.create_remediation(topic, diagnosis)
        assert is_binary(result)
        assert String.contains?(result, "procedural")
        assert String.contains?(result, "Applied operations to wrong side")
        assert String.contains?(result, "step by step")
      end
    end
    
    test "handles map topic with name key" do
      topic = %{name: "Geometry"}
      diagnosis = %{"error_category" => "measurement", "misconception" => "confused units"}
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:error, :network_error} end]) do
        assert {:ok, result} = Tools.create_remediation(topic, diagnosis)
        assert is_binary(result)
        assert String.contains?(result, "measurement")
      end
    end
  end

  describe "explain_concept/2" do
    test "provides AI-generated concept explanation" do
      topic = %{name: "Quadratic Equations"}
      message = "Why do we complete the square?"
      
      explanation = """
      Great question! Completing the square is a powerful technique for solving quadratic equations.
      
      You asked: "Why do we complete the square?"
      
      We complete the square because:
      1. It transforms any quadratic into a perfect square trinomial
      2. This makes it easier to solve by taking square roots
      3. It reveals the vertex form, showing us the maximum or minimum point
      4. It's especially useful when the quadratic doesn't factor nicely
      
      Think of it as "rearranging" the equation into a form that's easier to work with, like organizing your room to find things more easily!
      """
      
      api_response = %{
        status: 200,
        body: %{
          "choices" => [
            %{
              "message" => %{
                "content" => explanation
              }
            }
          ]
        }
      }
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:ok, api_response} end]) do
        assert {:ok, result} = Tools.explain_concept(topic, message)
        assert is_binary(result)
        assert String.contains?(result, message)
        assert String.contains?(result, "complete the square")
        assert String.contains?(result, "vertex form")
      end
    end
    
    test "provides fallback explanation when API fails" do
      topic = "Statistics"
      message = "What is standard deviation?"
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:error, :api_error} end]) do
        assert {:ok, result} = Tools.explain_concept(topic, message)
        assert is_binary(result)
        assert String.contains?(result, message)
        assert String.contains?(result, "Statistics")
        assert String.contains?(result, "step by step")
      end
    end
    
    test "handles string topic" do
      topic = "Trigonometry"
      message = "What is sine?"
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:error, :network_error} end]) do
        assert {:ok, result} = Tools.explain_concept(topic, message)
        assert is_binary(result)
        assert String.contains?(result, message)
        assert String.contains?(result, topic)
      end
    end
    
    test "handles nil topic gracefully" do
      message = "What is mathematics?"
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:error, :timeout} end]) do
        assert {:ok, result} = Tools.explain_concept(nil, message)
        assert is_binary(result)
        assert String.contains?(result, message)
        assert String.contains?(result, "this concept")
      end
    end
  end

  describe "provide_hint/2" do
    test "provides AI-generated hint" do
      question = %{"text" => "Find the area of a circle with radius 5cm"}
      context = "Student forgot the formula"
      
      hint_text = """
      Here's a hint for finding the area of a circle:
      
      Remember the area formula for a circle: A = πr²
      
      You have the radius (5cm), so think about:
      - What does r² mean when r = 5?
      - What value do we use for π?
      
      Try substituting the values into the formula step by step.
      """
      
      api_response = %{
        status: 200,
        body: %{
          "choices" => [
            %{
              "message" => %{
                "content" => hint_text
              }
            }
          ]
        }
      }
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:ok, api_response} end]) do
        assert {:ok, result} = Tools.provide_hint(question, context)
        assert is_binary(result)
        assert String.contains?(result, "A = πr²")
        assert String.contains?(result, "step by step")
      end
    end
    
    test "provides fallback hint when API fails" do
      question = %{"text" => "Solve: 3x - 7 = 14"}
      context = "Student is stuck on first step"
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:error, :timeout} end]) do
        assert {:ok, result} = Tools.provide_hint(question, context)
        assert is_binary(result)
        assert String.contains?(result, "3x - 7 = 14")
        assert String.contains?(result, context)
        assert String.contains?(result, "smaller steps")
      end
    end
    
    test "handles question without text field" do
      question = %{"topic" => "geometry"}
      context = "Help with angles"
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:error, :network_error} end]) do
        assert {:ok, result} = Tools.provide_hint(question, context)
        assert is_binary(result)
        assert String.contains?(result, "the problem")
        assert String.contains?(result, context)
      end
    end
  end
  
  describe "API error handling" do
    test "handles HTTP 429 rate limit error" do
      question = %{"text" => "Test question", "correct_answer" => "42"}
      
      api_response = %{
        status: 429,
        body: %{"error" => %{"message" => "Rate limit exceeded"}}
      }
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:ok, api_response} end]) do
        assert {:ok, result} = Tools.check_answer(question, "42")
        # Should fall back to simple comparison
        assert result["is_correct"] == true
      end
    end
    
    test "handles HTTP 500 server error" do
      topic = "Test Topic"
      
      api_response = %{
        status: 500,
        body: %{"error" => "Internal server error"}
      }
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:ok, api_response} end]) do
        assert {:ok, result} = Tools.generate_question(topic)
        # Should fall back to mock question
        assert String.contains?(result["text"], "Test Topic")
      end
    end
    
    test "handles network timeout gracefully" do
      diagnosis = %{"error_category" => "test", "misconception" => "test error"}
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:error, %{reason: :timeout}} end]) do
        assert {:ok, result} = Tools.create_remediation("Test", diagnosis)
        assert is_binary(result)
        assert String.contains?(result, "test")
      end
    end
    
    test "handles empty API key environment variable" do
      # Remove API key
      System.delete_env("OPENAI_API_KEY")
      
      question = %{"text" => "What is 5 + 3?", "correct_answer" => "8"}
      
      assert {:ok, result} = Tools.check_answer(question, "8")
      # Should use fallback
      assert result["is_correct"] == true
      assert String.contains?(result["explanation"], "fallback mode")
      
      # Restore API key
      System.put_env("OPENAI_API_KEY", "test-api-key")
    end
    
    test "handles malformed API response structure" do
      question = %{"text" => "Test", "correct_answer" => "answer"}
      
      # API response missing expected structure
      api_response = %{
        status: 200,
        body: %{"unexpected" => "structure"}
      }
      
      with_mock(Req, [:passthrough], [post: fn _, _ -> {:ok, api_response} end]) do
        assert {:ok, result} = Tools.check_answer(question, "answer")
        # Should fall back gracefully
        assert result["is_correct"] == true
      end
    end
  end
end