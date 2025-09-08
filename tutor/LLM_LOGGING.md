# LLM Logging Configuration

This document explains the comprehensive LLM logging system implemented in the Tutor application.

## Overview

All LLM (Large Language Model) requests and responses are logged with detailed information to help with debugging, monitoring, and understanding the AI tutoring interactions.

## Log Format

### Request Logs
```
🤖 LLM Request [request_id] - Provider: Module.Name
🤖 LLM Request [request_id] - Messages: [detailed message content]
🤖 LLM Request [request_id] - Options: %{temperature: 0.7, max_tokens: 1000}
```

### Response Logs
```
🤖 LLM Response [request_id] - Duration: 1234ms
🤖 LLM Response [request_id] - Success: "LLM response content"
```

### Tool Call Logs
```
🛠️ Tool Call: generate_question
🛠️ Tool Result: generate_question completed in 1234ms
```

### Error Logs
```
🤖 LLM Response [request_id] - Duration: 1234ms
🤖 LLM Response [request_id] - Error: %{reason: "API timeout"}
```

## Configuration

Configure LLM logging in `config/config.exs`:

```elixir
config :tutor, :llm_logging,
  enabled: true,           # Enable/disable all LLM logging
  log_requests: true,      # Log outgoing requests
  log_responses: true,     # Log incoming responses
  log_full_content: true   # Log full message content vs truncated
```

### Configuration Options

- **enabled**: Master switch for all LLM logging
- **log_requests**: Whether to log outgoing API requests
- **log_responses**: Whether to log incoming API responses
- **log_full_content**: 
  - `true`: Log complete message content (recommended for development)
  - `false`: Log truncated content for privacy/brevity (recommended for production)

## Log Levels

- **INFO**: Request/response summaries, tool calls, timing information
- **ERROR**: API errors, configuration issues, failures
- **DEBUG**: Detailed prompts and full response content (only visible when logger level is set to `:debug`)

## Request Tracking

Each LLM request gets a unique 8-character hex ID for correlation:
- Requests and responses are matched by the same ID
- Helps trace conversations across async operations
- Useful for debugging complex multi-step interactions

## Tool Function Tracking

The system automatically detects which tool function triggered each LLM call:
- `generate_question`
- `check_answer`  
- `diagnose_error`
- `create_remediation`
- `explain_concept`
- `classify_intent`
- `provide_hint`

## Privacy Considerations

When `log_full_content: false`:
- Messages are truncated to first 100 characters
- Responses are truncated to first 200 characters
- Full logging is still available for debugging when needed

## Performance Impact

- Logging adds minimal overhead (typically <1ms per request)
- Request timing includes the logging overhead
- Consider setting `enabled: false` in production if performance is critical

## Example Log Output

```
[info] 🛠️ Tool Call: generate_question
[info] 🤖 LLM Request [a1b2c3d4] - Provider: Elixir.Tutor.LLM.Providers.OpenAI
[info] 🤖 LLM Request [a1b2c3d4] - Messages: [%{content: "You are an expert GCSE Mathematics tutor...", role: "system"}, %{content: "Generate a GCSE Mathematics question for the topic: Algebra...", role: "user"}]
[info] 🤖 LLM Request [a1b2c3d4] - Options: %{max_tokens: 1000, temperature: 0.7}
[info] 🤖 LLM Response [a1b2c3d4] - Duration: 1847ms
[info] 🤖 LLM Response [a1b2c3d4] - Success: "{\n  \"text\": \"Solve for x: 3x + 7 = 22\",\n  \"topic\": \"Algebra\",\n  \"type\": \"open_ended\",\n  \"correct_answer\": \"x = 5\",\n  \"difficulty\": \"foundation\",\n  \"hint\": \"Subtract 7 from both sides first\"\n}"
[info] 🛠️ Tool Result: generate_question completed in 1847ms
```

## Troubleshooting

### No LLM logs appearing
1. Check that `:llm_logging, :enabled` is `true` in config
2. Verify logger level allows `:info` messages
3. Ensure LLM provider is properly configured

### Truncated log content
- Set `log_full_content: true` to see complete messages
- Use `mix phx.server` with `--verbose` flag for more detail

### Performance issues
- Set `enabled: false` to disable all LLM logging
- Or set `log_full_content: false` to reduce log volume