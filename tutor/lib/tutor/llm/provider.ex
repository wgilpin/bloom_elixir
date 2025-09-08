defmodule Tutor.LLM.Provider do
  @moduledoc """
  Behaviour for LLM providers. Implement this behaviour to add support
  for different LLM services (OpenAI, Gemini, Grok, etc.).
  """

  @type message :: %{
    role: String.t(),
    content: String.t()
  }

  @type options :: %{
    optional(:temperature) => float(),
    optional(:max_tokens) => integer(),
    optional(:model) => String.t()
  }

  @type response :: {:ok, String.t()} | {:error, term()}

  @doc """
  Sends a chat completion request to the LLM provider.
  
  ## Parameters
    - messages: List of message maps with role and content
    - opts: Provider-specific options (temperature, max_tokens, model, etc.)
  
  ## Returns
    - {:ok, response_text} on success
    - {:error, reason} on failure
  """
  @callback chat_completion(messages :: [message()], opts :: options()) :: response()

  @doc """
  Returns the default model for this provider.
  """
  @callback default_model() :: String.t()

  @doc """
  Validates that the provider is properly configured.
  Returns {:ok, config} if valid, {:error, reason} if not.
  """
  @callback validate_config() :: {:ok, map()} | {:error, String.t()}
end