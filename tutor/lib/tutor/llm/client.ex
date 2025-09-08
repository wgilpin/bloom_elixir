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
    
    # Generate unique request ID for tracking
    request_id = generate_request_id()
    
    # Get logging configuration (returns keyword list)
    llm_logging = Application.get_env(:tutor, :llm_logging, [])
    enabled = Keyword.get(llm_logging, :enabled, true)
    log_requests = Keyword.get(llm_logging, :log_requests, true)
    log_responses = Keyword.get(llm_logging, :log_responses, true)
    log_full_content = Keyword.get(llm_logging, :log_full_content, true)
    
    # Get retry configuration
    max_retries = Keyword.get(opts, :max_retries, 3)
    retry_delay = Keyword.get(opts, :retry_delay, 1000)
    
    # Execute with retry logic
    execute_with_retry(
      fn -> execute_request(provider, messages, opts, request_id, llm_logging) end,
      max_retries,
      retry_delay,
      request_id,
      enabled
    )
  end
  
  defp execute_request(provider, messages, opts, request_id, llm_logging) do
    enabled = Keyword.get(llm_logging, :enabled, true)
    log_requests = Keyword.get(llm_logging, :log_requests, true)
    log_responses = Keyword.get(llm_logging, :log_responses, true)
    log_full_content = Keyword.get(llm_logging, :log_full_content, true)
    
    # Log request details if enabled
    if enabled and log_requests do
      Logger.info("🤖 LLM Request [#{request_id}] - Provider: #{inspect(provider)}")
      if log_full_content do
        Logger.info("🤖 LLM Request [#{request_id}] - Messages: #{inspect(messages, limit: :infinity, printable_limit: :infinity)}")
      else
        message_summary = messages
        |> Enum.map(fn %{role: role, content: content} ->
          truncated_content = if String.length(content) > 100 do
            String.slice(content, 0, 97) <> "..."
          else
            content
          end
          "#{role}: #{truncated_content}"
        end)
        |> Enum.join(" | ")
        Logger.info("🤖 LLM Request [#{request_id}] - Messages: #{message_summary}")
      end
      Logger.info("🤖 LLM Request [#{request_id}] - Options: #{inspect(opts)}")
    end
    
    start_time = System.monotonic_time()
    
    result = case provider.validate_config() do
      {:ok, _} ->
        provider.chat_completion(messages, opts)
        
      {:error, reason} = error ->
        if enabled do
          Logger.error("🤖 LLM Request [#{request_id}] - Configuration invalid: #{reason}")
        end
        error
    end
    
    end_time = System.monotonic_time()
    duration_ms = System.convert_time_unit(end_time - start_time, :native, :millisecond)
    
    # Log response details if enabled
    if enabled and log_responses do
      case result do
        {:ok, response_text} ->
          Logger.info("🤖 LLM Response [#{request_id}] - Duration: #{duration_ms}ms")
          if log_full_content do
            Logger.info("🤖 LLM Response [#{request_id}] - Success: #{inspect(response_text, limit: :infinity, printable_limit: :infinity)}")
          else
            truncated_response = if String.length(response_text) > 200 do
              String.slice(response_text, 0, 197) <> "..."
            else
              response_text
            end
            Logger.info("🤖 LLM Response [#{request_id}] - Success: #{truncated_response}")
          end
          
        {:error, reason} ->
          Logger.error("🤖 LLM Response [#{request_id}] - Duration: #{duration_ms}ms")
          Logger.error("🤖 LLM Response [#{request_id}] - Error: #{inspect(reason)}")
      end
    end
    
    result
  end
  
  defp execute_with_retry(fun, max_retries, retry_delay, request_id, logging_enabled, attempt \\ 1) do
    case fun.() do
      {:ok, _} = success ->
        success
        
      {:error, reason} = error ->
        if should_retry?(reason) and attempt < max_retries do
          delay = retry_delay * attempt  # Exponential backoff
          if logging_enabled do
            Logger.warning("🔄 LLM Request [#{request_id}] - Retry #{attempt}/#{max_retries} after #{delay}ms due to: #{inspect(reason)}")
          end
          Process.sleep(delay)
          execute_with_retry(fun, max_retries, retry_delay, request_id, logging_enabled, attempt + 1)
        else
          if logging_enabled and attempt == max_retries do
            Logger.error("🔴 LLM Request [#{request_id}] - Failed after #{max_retries} retries")
          end
          error
        end
    end
  end
  
  defp should_retry?(reason) do
    case reason do
      {:request_failed, %Req.TransportError{reason: :closed}} -> true
      {:request_failed, %Req.TransportError{reason: :timeout}} -> true
      {:request_failed, %Req.TransportError{reason: :econnrefused}} -> true
      {:request_failed, %Req.TransportError{}} -> true
      {:request_failed, %{status: status}} when status >= 500 -> true
      {:request_failed, %{status: 429}} -> true  # Rate limited
      _ -> false
    end
  end
  
  defp generate_request_id do
    :crypto.strong_rand_bytes(4)
    |> Base.encode16(case: :lower)
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