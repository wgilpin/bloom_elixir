defmodule Tutor.LLM.Providers.Grok do
  @moduledoc """
  xAI Grok provider implementation for chat completions.
  Supports Grok-1 and other xAI models.
  """
  
  @behaviour Tutor.LLM.Provider
  
  require Logger
  
  @api_url "https://api.x.ai/v1/chat/completions"
  @default_model "grok-2-1212"
  
  defp get_model do
    System.get_env("GROK_MODEL") || @default_model
  end
  @request_timeout 30_000
  
  @impl true
  def chat_completion(messages, opts \\ %{}) do
    with {:ok, config} <- validate_config() do
      make_request(messages, opts, config)
    end
  end
  
  @impl true
  def default_model, do: @default_model
  
  @impl true
  def validate_config do
    api_key = System.get_env("GROK_API_KEY") || System.get_env("XAI_API_KEY")
    
    if api_key && api_key != "" do
      {:ok, %{api_key: api_key}}
    else
      {:error, "GROK_API_KEY or XAI_API_KEY environment variable not set"}
    end
  end
  
  defp make_request(messages, opts, config) do
    request_body = build_request_body(messages, opts)
    headers = build_headers(config.api_key)
    
    Logger.debug("Grok request body: #{inspect(request_body)}")
    
    case Req.post(@api_url,
      json: request_body,
      headers: headers,
      receive_timeout: opts[:timeout] || @request_timeout
    ) do
      {:ok, %{status: 200, body: body}} ->
        Logger.debug("Grok API response body: #{inspect(body)}")
        
        case extract_content_from_response(body) do
          {:ok, content} ->
            {:ok, String.trim(content)}
            
          {:error, reason} ->
            {:error, reason}
        end
        
      {:ok, %{status: status, body: body}} ->
        Logger.error("Grok API error: #{status} - #{inspect(body)}")
        {:error, {:api_error, status, body}}
        
      {:error, reason} ->
        Logger.error("Grok request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end
  
  defp build_request_body(messages, opts) do
    %{
      model: opts[:model] || get_model(),
      messages: messages,
      temperature: opts[:temperature] || 0.7,
      max_tokens: opts[:max_tokens] || 4000,
      stream: opts[:stream] || false
    }
    |> maybe_add_optional_params(opts)
  end
  
  defp maybe_add_optional_params(body, opts) do
    body
    |> maybe_add_param(:top_p, opts[:top_p])
    |> maybe_add_param(:n, opts[:n])
    |> maybe_add_param(:stop, opts[:stop])
    |> maybe_add_param(:presence_penalty, opts[:presence_penalty])
    |> maybe_add_param(:frequency_penalty, opts[:frequency_penalty])
  end
  
  defp maybe_add_param(body, _key, nil), do: body
  defp maybe_add_param(body, key, value), do: Map.put(body, key, value)
  
  defp build_headers(api_key) do
    [
      {"authorization", "Bearer #{api_key}"},
      {"content-type", "application/json"}
    ]
  end
  
  # Extract content from Grok response, checking both content and reasoning_content fields
  defp extract_content_from_response(body) do
    case body do
      %{"choices" => [choice | _]} ->
        # Check for regular content first
        regular_content = get_in(choice, ["message", "content"])
        # Check for reasoning content (Grok sometimes uses this field)
        reasoning_content = get_in(choice, ["message", "reasoning_content"])
        
        cond do
          is_binary(regular_content) and regular_content != "" ->
            {:ok, regular_content}
            
          is_binary(reasoning_content) and reasoning_content != "" ->
            Logger.debug("Using reasoning_content from Grok response")
            {:ok, reasoning_content}
            
          true ->
            Logger.error("Grok returned empty content in both content and reasoning_content fields")
            {:error, {:empty_response, "LLM returned empty content"}}
        end
        
      other ->
        Logger.error("Unexpected Grok response structure: #{inspect(other)}")
        {:error, {:unexpected_response, other}}
    end
  end
end