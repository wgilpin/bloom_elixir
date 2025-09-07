# Testing Guide

## Overview

This project includes comprehensive unit tests for the pedagogical state machine and LLM-based modules. The testing strategy separates concerns by mocking external dependencies (LLM calls) while testing core logic.

## Test Structure

### Current Test Coverage

1. **PedagogicalStateMachine** - Full unit test coverage (31 tests, all passing)
   - State transition logic
   - Event validation
   - Flow pattern verification
   - Complete state machine scenarios

2. **Tools Module** - Updated for new return format (14 tests, all passing)
   - Mock LLM responses with `{:ok, result}` tuples
   - Error handling
   - Parameter validation

3. **ErrorDiagnosisEngine & AdaptiveIntervention** - Framework prepared but needs configuration fix
   - Comprehensive test scenarios created
   - Mox setup for LLM mocking
   - Tests require runtime module injection fix

### Running Tests

```bash
# Run all tests
mix test

# Run specific module tests
mix test test/tutor_ex/learning/pedagogical_state_machine_test.exs
mix test test/tutor/tools_test.exs

# Run tests with coverage
mix test --cover
```

## LLM Mocking Strategy

### Current Implementation

The project uses **Mox** for clean LLM mocking with these components:

1. **Mock Behaviour** (`test/support/tools_mock.ex`)
   ```elixir
   defmodule Tutor.Tools.MockBehaviour do
     @callback generate_question(topic :: any()) :: {:ok, map()} | {:error, String.t()}
     @callback check_answer(question :: map(), student_answer :: String.t()) :: {:ok, map()} | {:error, String.t()}
     # ... other LLM functions
   end
   ```

2. **Test Configuration** (`test_helper.exs`)
   ```elixir
   Mox.defmock(Tutor.Tools.Mock, for: Tutor.Tools.MockBehaviour)
   Application.put_env(:tutor, :tools_module, Tutor.Tools.Mock)
   ```

3. **Runtime Module Injection** - Modules use configurable module references:
   ```elixir
   @tools_module Application.compile_env(:tutor, :tools_module, Tutor.Tools)
   defp tools_module, do: @tools_module
   ```

### Test Example

```elixir
test "diagnoses error using LLM" do
  Tutor.Tools.Mock
  |> expect(:diagnose_error, fn _question, _data ->
    {:ok, %{
      "error_identified" => true,
      "error_category" => "arithmetic",
      "confidence" => 0.85
    }}
  end)

  assert {:ok, diagnosis} = ErrorDiagnosisEngine.diagnose_error(question, check_result, answer)
  assert diagnosis.error_type == :known
  assert diagnosis.confidence == 0.85
end
```

## Testing Philosophy

### What We Test

1. **State Machine Logic** - Pure functions, deterministic state transitions
2. **Error Handling** - Graceful degradation when LLM services fail
3. **Data Transformation** - Parsing and structuring LLM responses
4. **Business Logic** - Educational flow and intervention strategies

### What We Mock

1. **LLM API Calls** - External service dependencies
2. **Network Requests** - HTTP calls to AI services
3. **Async Tool Execution** - Long-running operations

### What We Don't Mock

1. **Core Educational Logic** - The pedagogical state machine
2. **Data Structures** - Internal state management
3. **Pure Functions** - Deterministic calculations and transformations

## Integration Testing

For integration testing with real LLM services:

```elixir
# config/test.exs
config :tutor, :tools_module, Tutor.Tools  # Use real module

# Run integration tests
MIX_ENV=integration mix test --only integration
```

## Future Testing Enhancements

1. **Property-Based Testing** - Use StreamData for state machine edge cases
2. **Integration Test Suite** - Automated testing with real LLM services
3. **Performance Testing** - Load testing for concurrent sessions
4. **End-to-End Testing** - Full user journey through Phoenix channels

## Test Data Management

### Mock Responses

Store common LLM response patterns in test fixtures:

```elixir
# test/fixtures/llm_responses.ex
defmodule TestFixtures.LLMResponses do
  def successful_diagnosis do
    %{
      "error_identified" => true,
      "error_category" => "arithmetic",
      "error_description" => "Basic addition error",
      "confidence" => 0.8
    }
  end
end
```

### Question Banks

Create reusable test questions for consistent testing:

```elixir
def sample_arithmetic_question do
  %{
    "text" => "What is 2 + 2?",
    "topic" => "arithmetic",
    "correct_answer" => "4",
    "difficulty" => "basic"
  }
end
```

## Debugging Tests

1. **Verbose Output** - `mix test --trace`
2. **Focus Tests** - `@tag :focus` and `mix test --only focus`
3. **Mock Verification** - Use `verify_on_exit!` to catch unused expectations
4. **State Inspection** - Add debug logging in state transitions

## Performance Considerations

- Mock responses should be fast (< 1ms)
- Avoid actual LLM calls in unit tests
- Use async: true for parallel test execution
- Keep test data small and focused

## Maintenance

- Update mock responses when LLM API contracts change
- Regularly run integration tests against real services
- Keep test coverage above 90% for core logic
- Review and update test scenarios as features evolve