# LLM Provider Configuration

This application now supports multiple LLM providers. You can easily switch between OpenAI, Google Gemini, and xAI Grok.

## Supported Providers

### 1. OpenAI (Default)
- Models: GPT-3.5, GPT-4, GPT-4o-mini
- Required: `OPENAI_API_KEY` environment variable
- Get API key: https://platform.openai.com/api-keys

### 2. Google Gemini
- Models: gemini-2.5-flash
- Required: `GEMINI_API_KEY` or `GOOGLE_API_KEY` environment variable
- Get API key: https://makersuite.google.com/app/apikey

### 3. xAI Grok
- Models: grok-3-mini
- Required: `GROK_API_KEY` or `XAI_API_KEY` environment variable
- Get API key: https://x.ai/api

## Configuration

### Method 1: Environment Variable (Recommended)

Set the `LLM_PROVIDER` environment variable:

```bash
# Use OpenAI (default)
export LLM_PROVIDER=openai
export OPENAI_API_KEY=your-api-key

# Use Google Gemini
export LLM_PROVIDER=gemini
export GEMINI_API_KEY=your-api-key

# Use xAI Grok
export LLM_PROVIDER=grok
export GROK_API_KEY=your-api-key
```

### Method 2: Application Config

Edit `config/config.exs` or environment-specific config:

```elixir
# config/config.exs or config/dev.exs
config :tutor, :llm_provider, "gemini"  # or "openai", "grok"
```

### Method 3: Runtime Configuration

You can also check/change the provider at runtime:

```elixir
# In IEx console
iex> Tutor.LLM.Client.provider_info()
{:ok, %{provider: "OpenAI", default_model: "gpt-4o-mini", configured: true}}

# Check current provider
iex> Tutor.LLM.Client.get_provider()
Tutor.LLM.Providers.OpenAI
```

## Provider-Specific Notes

### OpenAI
- Most mature and stable API
- Best for complex reasoning tasks
- Higher cost per token
- Rate limits apply

### Google Gemini
- Free tier available
- Good performance for educational content
- Automatic safety filtering
- No system role (merged with user messages)

### xAI Grok
- Newer service, may have availability limitations
- Competitive pricing
- Good for factual and technical content
- OpenAI-compatible API format

## Testing Your Configuration

After setting up your provider, test it:

```elixir
# Start the application
mix phx.server

# Or in IEx:
iex -S mix phx.server

# Test the configuration
iex> Tutor.LLM.Client.validate_configuration()
{:ok, %{api_key: "sk-..."}}

# Test a simple completion
iex> messages = [
  %{role: "system", content: "You are a helpful assistant."},
  %{role: "user", content: "What is 2+2?"}
]
iex> Tutor.LLM.Client.chat_completion(messages)
{:ok, "2 + 2 equals 4."}
```

## Fallback Behavior

If the LLM provider fails or is not configured:
1. The system logs the error
2. Falls back to simple rule-based responses
3. Ensures the tutoring session can continue

## Cost Considerations

- **OpenAI**: Pay per token, no free tier
- **Gemini**: Free tier available (60 requests/minute)
- **Grok**: Pay per token, competitive pricing

## Switching Providers

You can switch providers without code changes:

1. Stop the application
2. Set new environment variables
3. Restart the application

```bash
# Switch from OpenAI to Gemini
export LLM_PROVIDER=gemini
export GEMINI_API_KEY=your-gemini-key
mix phx.server
```

## Troubleshooting

### Provider not working?

1. Check API key is set:
   ```elixir
   iex> System.get_env("OPENAI_API_KEY")  # or GEMINI_API_KEY, GROK_API_KEY
   ```

2. Validate configuration:
   ```elixir
   iex> Tutor.LLM.Client.validate_configuration()
   ```

3. Check logs for errors:
   ```bash
   tail -f log/dev.log
   ```

### Rate limits?

Each provider has different rate limits. Consider:
- Implementing retry logic
- Using queue systems for high volume
- Caching common responses

## Adding New Providers

To add a new LLM provider:

1. Create a new module in `lib/tutor/llm/providers/`
2. Implement the `Tutor.LLM.Provider` behaviour
3. Add provider mapping in `Tutor.LLM.Client.get_provider/0`
4. Test thoroughly

Example structure:
```elixir
defmodule Tutor.LLM.Providers.YourProvider do
  @behaviour Tutor.LLM.Provider
  
  @impl true
  def chat_completion(messages, opts), do: # ...
  
  @impl true
  def default_model(), do: "your-model"
  
  @impl true
  def validate_config(), do: # ...
end
```