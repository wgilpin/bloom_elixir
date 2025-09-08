defmodule Tutor.LLM.Providers.Gemini do
  @moduledoc """
  Google Gemini provider implementation for chat completions.
  Supports Gemini Pro, Gemini Pro Vision, and other Gemini models.
  """
  
  @behaviour Tutor.LLM.Provider
  
  require Logger
  
  @base_url "https://generativelanguage.googleapis.com/v1beta"
  @default_model "gemini-pro"
  
  defp get_model do
    System.get_env("GEMINI_MODEL") || @default_model
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
    api_key = System.get_env("GEMINI_API_KEY") || System.get_env("GOOGLE_API_KEY")
    
    if api_key && api_key != "" do
      {:ok, %{api_key: api_key}}
    else
      {:error, "GEMINI_API_KEY or GOOGLE_API_KEY environment variable not set"}
    end
  end
  
  defp make_request(messages, opts, config) do
    model = opts[:model] || get_model()
    url = build_url(model, config.api_key)
    request_body = build_request_body(messages, opts)
    headers = build_headers()
    
    case Req.post(url,
      json: request_body,
      headers: headers,
      receive_timeout: opts[:timeout] || @request_timeout
    ) do
      {:ok, %{status: 200, body: %{"candidates" => [%{"content" => %{"parts" => [%{"text" => text} | _]}} | _]}}} ->
        {:ok, String.trim(text)}
        
      {:ok, %{status: status, body: body}} ->
        Logger.error("Gemini API error: #{status} - #{inspect(body)}")
        {:error, {:api_error, status, body}}
        
      {:error, reason} ->
        Logger.error("Gemini request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end
  
  defp build_url(model, api_key) do
    "#{@base_url}/models/#{model}:generateContent?key=#{api_key}"
  end
  
  defp build_request_body(messages, opts) do
    %{
      contents: convert_messages_to_gemini_format(messages),
      generationConfig: %{
        temperature: opts[:temperature] || 0.7,
        maxOutputTokens: opts[:max_tokens] || 1000,
        topP: opts[:top_p] || 0.95,
        topK: opts[:top_k] || 40
      }
    }
    |> maybe_add_safety_settings(opts)
  end
  
  defp convert_messages_to_gemini_format(messages) do
    messages
    |> Enum.map(fn message ->
      role = case message.role do
        "system" -> "user"  # Gemini doesn't have system role, merge with user
        "assistant" -> "model"
        other -> other
      end
      
      %{
        role: role,
        parts: [%{text: message.content}]
      }
    end)
    |> merge_consecutive_user_messages()
  end
  
  defp merge_consecutive_user_messages(messages) do
    messages
    |> Enum.reduce([], fn message, acc ->
      case {acc, message.role} do
        {[], _} ->
          [message]
          
        {[%{role: "user", parts: parts} | rest], "user"} ->
          # Merge consecutive user messages
          merged = %{role: "user", parts: parts ++ message.parts}
          [merged | rest]
          
        {acc, _} ->
          [message | acc]
      end
    end)
    |> Enum.reverse()
  end
  
  defp maybe_add_safety_settings(body, opts) do
    if opts[:safety_settings] do
      Map.put(body, :safetySettings, opts[:safety_settings])
    else
      # Default safety settings for educational content
      Map.put(body, :safetySettings, [
        %{
          category: "HARM_CATEGORY_HARASSMENT",
          threshold: "BLOCK_MEDIUM_AND_ABOVE"
        },
        %{
          category: "HARM_CATEGORY_HATE_SPEECH",
          threshold: "BLOCK_MEDIUM_AND_ABOVE"
        },
        %{
          category: "HARM_CATEGORY_SEXUALLY_EXPLICIT",
          threshold: "BLOCK_MEDIUM_AND_ABOVE"
        },
        %{
          category: "HARM_CATEGORY_DANGEROUS_CONTENT",
          threshold: "BLOCK_MEDIUM_AND_ABOVE"
        }
      ])
    end
  end
  
  defp build_headers do
    [
      {"content-type", "application/json"}
    ]
  end
end