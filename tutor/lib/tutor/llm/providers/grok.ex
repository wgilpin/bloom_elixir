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
    
    case Req.post(@api_url,
      json: request_body,
      headers: headers,
      receive_timeout: opts[:timeout] || @request_timeout
    ) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}} ->
        {:ok, String.trim(content)}
        
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
      max_tokens: opts[:max_tokens] || 1000,
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
end