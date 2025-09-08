defmodule Tutor.LLM.Client do
  @moduledoc """
  Main client for interacting with LLM providers.
  Automatically selects and uses the configured provider.
  """
  
  require Logger
  
  @doc """
  Gets the currently configured LLM provider module.
  
  Provider can be set via:
  1. LLM_PROVIDER environment variable (e.g., "openai", "gemini", "grok")
  2. Application config: config :tutor, :llm_provider, "gemini"
  3. Defaults to "openai" if not specified
  """
  def get_provider do
    provider_name = 
      System.get_env("LLM_PROVIDER") ||
      Application.get_env(:tutor, :llm_provider) ||
      "openai"
    
    case String.downcase(provider_name) do
      "openai" -> Tutor.LLM.Providers.OpenAI
      "gemini" -> Tutor.LLM.Providers.Gemini
      "grok" -> Tutor.LLM.Providers.Grok
      "xai" -> Tutor.LLM.Providers.Grok
      other ->
        Logger.warning("Unknown LLM provider '#{other}', falling back to OpenAI")
        Tutor.LLM.Providers.OpenAI
    end
  end
  
  @doc """
  Sends a chat completion request to the configured LLM provider.
  
  ## Parameters
    - messages: List of message maps with :role and :content keys
    - opts: Optional parameters (model, temperature, max_tokens, etc.)
  
  ## Returns
    - {:ok, response_text} on success
    - {:error, reason} on failure
  """
  def chat_completion(messages, opts \\ %{}) do
    provider = get_provider()
    
    Logger.debug("Using LLM provider: #{inspect(provider)}")
    
    case provider.validate_config() do
      {:ok, _} ->
        provider.chat_completion(messages, opts)
        
      {:error, reason} = error ->
        Logger.error("LLM provider configuration invalid: #{reason}")
        error
    end
  end
  
  @doc """
  Returns information about the current provider configuration.
  """
  def provider_info do
    provider = get_provider()
    
    with {:ok, _config} <- provider.validate_config() do
      {:ok, %{
        provider: provider |> Module.split() |> List.last(),
        default_model: provider.default_model(),
        configured: true
      }}
    else
      {:error, reason} ->
        {:error, %{
          provider: provider |> Module.split() |> List.last(),
          error: reason,
          configured: false
        }}
    end
  end
  
  @doc """
  Helper to format messages consistently across providers.
  Ensures messages have the correct structure.
  """
  def format_message(role, content) when is_binary(role) and is_binary(content) do
    %{role: role, content: content}
  end
  
  @doc """
  Validates that all required environment variables are set for the current provider.
  """
  def validate_configuration do
    provider = get_provider()
    provider.validate_config()
  end
end