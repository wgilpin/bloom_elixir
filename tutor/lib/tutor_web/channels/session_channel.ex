defmodule TutorWeb.SessionChannel do
  use TutorWeb, :channel
  require Logger

  alias Tutor.Learning.{SessionServer, SessionSupervisor}

  @impl true
  def join("session:" <> session_id, _payload, socket) do
    Logger.info("User #{socket.assigns.user_id} joining session #{session_id}")
    
    # Validate that user can join this session
    case authorize_session_access(socket.assigns.user_id, session_id) do
      {:ok, session} ->
        socket = 
          socket
          |> assign(:session_id, session_id)
          |> assign(:session, session)
        
        {:ok, socket}
      
      {:error, reason} ->
        Logger.warning("Failed to join session #{session_id}: #{inspect(reason)}")
        {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("user_message", %{"content" => content}, socket) do
    Logger.info("Received user message in session #{socket.assigns.session_id}")
    
    # Route message to SessionServer (placeholder for now)
    case route_to_session_server(socket.assigns.session_id, content, socket.assigns.user_id) do
      {:ok, response} ->
        # Broadcast response back to client
        push(socket, "tutor_response", %{content: response})
        {:noreply, socket}
      
      {:error, reason} ->
        Logger.error("Failed to process message: #{inspect(reason)}")
        push(socket, "error", %{reason: "processing_failed"})
        {:noreply, socket}
    end
  end

  @impl true
  def handle_in("ping", _payload, socket) do
    push(socket, "pong", %{})
    {:noreply, socket}
  end

  @impl true
  def handle_in(event, payload, socket) do
    Logger.warning("Unknown event received: #{event} with payload: #{inspect(payload)}")
    push(socket, "error", %{reason: "unknown_event", event: event})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:tutor_response, content}, socket) do
    # Handle async responses from SessionServer
    push(socket, "tutor_response", %{content: content})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:session_state_changed, state}, socket) do
    # Notify client of state changes (e.g., awaiting_answer -> remediating)
    push(socket, "state_change", %{state: state})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:error, reason}, socket) do
    # Handle error notifications from SessionServer
    push(socket, "error", %{reason: reason})
    {:noreply, socket}
  end

  @impl true
  def handle_info(msg, socket) do
    Logger.warning("Unexpected message received: #{inspect(msg)}")
    {:noreply, socket}
  end

  @impl true
  def terminate(reason, socket) do
    Logger.info("Session channel terminating: #{inspect(reason)}")
    
    # Notify SessionServer that user disconnected (if session exists)
    if socket.assigns[:session_id] do
      notify_session_server_disconnect(socket.assigns.session_id, socket.assigns.user_id)
    end
    
    :ok
  end

  # Private functions

  defp authorize_session_access(user_id, session_id) do
    # TODO: Implement proper authorization
    # For now, allow any user to access any session
    # In production, check if user owns session or is authorized to access it
    {:ok, %{id: session_id, user_id: user_id}}
  end

  defp route_to_session_server(session_id, content, user_id) do
    Logger.info("Routing message to SessionServer for session #{session_id}")
    
    # Ensure session exists, creating if necessary
    case ensure_session_exists(session_id, user_id) do
      {:ok, _pid} ->
        # Send message to SessionServer
        case SessionServer.handle_user_message(session_id, content) do
          {:ok, new_state} ->
            # Get the latest conversation to find the response
            state = SessionServer.get_state(session_id)
            response = get_latest_system_response(state.conversation_history)
            {:ok, response}
          
          {:error, reason} ->
            Logger.error("SessionServer error: #{inspect(reason)}")
            {:error, :processing_failed}
        end
      
      {:error, reason} ->
        Logger.error("Failed to ensure session exists: #{inspect(reason)}")
        {:error, :session_unavailable}
    end
  end

  defp generate_mock_response(content) do
    cond do
      String.contains?(String.downcase(content), "hello") ->
        "Hello! I'm your AI tutor. What would you like to work on today?"
      
      String.contains?(String.downcase(content), "help") ->
        "I can help you with GCSE Mathematics. Try asking me about algebra, geometry, or any specific topic!"
      
      String.match?(content, ~r/\d+\s*[\+\-\*\/]\s*\d+/) ->
        "I can see you're working with numbers! Let me help you solve this step by step."
      
      true ->
        "I understand you said: '#{content}'. How can I help you learn mathematics today?"
    end
  end

  defp notify_session_server_disconnect(session_id, user_id) do
    Logger.info("User #{user_id} disconnected from session #{session_id}")
    # For now, we'll let the SessionServer handle its own cleanup
    # In the future, we might want to notify it of disconnections
    :ok
  end

  defp ensure_session_exists(session_id, user_id) do
    case SessionSupervisor.start_session(session_id, user_id) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_latest_system_response([]), do: "Hello! I'm your AI tutor. How can I help you today?"
  
  defp get_latest_system_response([%{role: :system, content: content} | _]) do
    content
  end
  
  defp get_latest_system_response([_ | rest]) do
    get_latest_system_response(rest)
  end
end