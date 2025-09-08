defmodule TutorWeb.SessionLive do
  use TutorWeb, :live_view
  alias Tutor.Learning.{SessionSupervisor, SessionRegistry}
  alias Tutor.Curriculum.Syllabus
  alias Tutor.Repo
  import Ecto.Query
  
  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"] || generate_user_id()
    session_id = "session_#{user_id}"
    
    # Start session server if not already running
    require Logger
    Logger.info("🚀 Starting SessionServer for user: #{user_id}, session: #{session_id}")
    
    case SessionSupervisor.start_session(user_id, session_id) do
      {:ok, _pid} -> 
        Logger.info("✅ SessionServer started successfully")
        :ok
      {:error, {:already_started, _pid}} -> 
        Logger.info("♻️ SessionServer already running")
        :ok
      {:error, reason} ->
        Logger.error("❌ Failed to start SessionServer: #{inspect(reason)}")
        :ok
    end
    
    # Subscribe to session updates
    Phoenix.PubSub.subscribe(Tutor.PubSub, "session:#{session_id}")
    
    # Load available topics for topic selection
    topics = load_syllabus_topics()
    
    socket = 
      socket
      |> assign(:user_id, user_id)
      |> assign(:session_id, session_id)
      |> assign(:messages, [])
      |> assign(:current_message, "")
      |> assign(:typing, false)
      |> assign(:waiting_for_response, false)
      |> assign(:view_state, :topic_selection)  # Start with topic selection
      |> assign(:available_topics, topics)
      |> assign(:selected_topic, nil)
    
    {:ok, socket}
  end
  
  @impl true
  def handle_event("select_topic", %{"topic_id" => topic_id}, socket) do
    topic_id = String.to_integer(topic_id)
    topic = Enum.find(socket.assigns.available_topics, &(&1.id == topic_id))
    
    if topic do
      require Logger
      Logger.info("📚 User selected topic: #{topic.topic} (ID: #{topic_id})")
      
      # Send topic to SessionServer
      case Registry.lookup(SessionRegistry, socket.assigns.session_id) do
        [{session_server_pid, _}] ->
          GenServer.cast(session_server_pid, {:set_topic, topic.topic})
        [] ->
          require Logger
          Logger.error("❌ SessionServer not found for session: #{socket.assigns.session_id}")
      end
      
      socket = 
        socket
        |> assign(:selected_topic, topic)
        |> assign(:view_state, :chat)
      
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("validate", %{"message" => message}, socket) do
    socket = assign(socket, :current_message, message)
    
    # Send typing indicator
    socket = if String.length(message) > 0 and not socket.assigns.typing do
      send_typing_indicator(socket.assigns.session_id, true)
      assign(socket, :typing, true)
    else
      socket
    end
    
    socket = if String.length(message) == 0 and socket.assigns.typing do
      send_typing_indicator(socket.assigns.session_id, false)
      assign(socket, :typing, false)
    else
      socket
    end
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("back_to_topics", _params, socket) do
    socket = assign(socket, :view_state, :topic_selection)
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    trimmed_message = String.trim(message)
    
    if trimmed_message != "" do
      # Add user message to chat
      user_message = %{
        id: :crypto.strong_rand_bytes(8) |> Base.encode16(),
        content: trimmed_message,
        sender: :user,
        timestamp: DateTime.utc_now()
      }
      
      messages = socket.assigns.messages ++ [user_message]
      
      # Send message to SessionServer via Registry lookup
      case Registry.lookup(SessionRegistry, socket.assigns.session_id) do
        [{session_server_pid, _}] ->
          require Logger
          Logger.info("📨 LiveView sending message to SessionServer: #{inspect(trimmed_message)}")
          GenServer.cast(session_server_pid, {:user_message, trimmed_message})
        [] ->
          require Logger
          Logger.error("❌ SessionServer not found for session: #{socket.assigns.session_id}")
          :ok
      end
      
      # Stop typing indicator
      send_typing_indicator(socket.assigns.session_id, false)
      
      socket = 
        socket
        |> assign(:messages, messages)
        |> assign(:current_message, "")
        |> assign(:typing, false)
        |> assign(:waiting_for_response, true)
      
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:session_response, response}, socket) do
    require Logger
    Logger.info("📨 LiveView received response from SessionServer: #{inspect(response)}")
    
    # Add assistant message to chat
    assistant_message = %{
      id: :crypto.strong_rand_bytes(8) |> Base.encode16(),
      content: response,
      sender: :assistant,
      timestamp: DateTime.utc_now()
    }
    
    messages = socket.assigns.messages ++ [assistant_message]
    
    socket = 
      socket
      |> assign(:messages, messages)
      |> assign(:waiting_for_response, false)
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:typing_indicator, is_typing}, socket) do
    socket = assign(socket, :assistant_typing, is_typing)
    {:noreply, socket}
  end
  
  @impl true
  def handle_info(_msg, socket) do
    # Handle other messages
    {:noreply, socket}
  end
  
  @impl true
  def terminate(_reason, socket) do
    # Clean up SessionServer when LiveView terminates
    case Registry.lookup(SessionRegistry, socket.assigns.session_id) do
      [{session_server_pid, _}] ->
        GenServer.cast(session_server_pid, :session_ended)
      [] ->
        :ok
    end
    
    :ok
  end
  
  # Private functions
  
  defp generate_user_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16()
  end
  
  defp send_typing_indicator(session_id, is_typing) do
    Phoenix.PubSub.broadcast(Tutor.PubSub, "session:#{session_id}", {:typing_indicator, is_typing})
  end
  
  defp format_timestamp(datetime) do
    datetime
    |> DateTime.to_time()
    |> Time.to_string()
    |> String.slice(0, 5)
  end
  
  defp render_message_content(content) do
    # Process markdown first
    case Earmark.as_html(content) do
      {:ok, html, _messages} -> 
        html
        |> String.replace(~r/<p>(.*?)<\/p>/, "\\1")
        |> process_math_delimiters()
      {:error, _html, _messages} -> 
        # Fallback to basic formatting if markdown fails
        content
        |> HtmlEntities.encode()
        |> String.replace(~r/\*\*(.*?)\*\*/, "<strong>\\1</strong>")
        |> String.replace(~r/\*(.*?)\*/, "<em>\\1</em>")
        |> String.replace(~r/`(.*?)`/, "<code>\\1</code>")
        |> String.replace(~r/\n/, "<br>")
        |> process_math_delimiters()
    end
  end
  
  defp process_math_delimiters(html) do
    html
    # Handle display math: $$...$$ 
    |> String.replace(~r/\$\$(.*?)\$\$/s, "<span class=\"math-display\">\\(\\1\\)</span>")
    # Handle inline math: $...$
    |> String.replace(~r/(?<!\$)\$(?!\$)(.*?)(?<!\$)\$(?!\$)/, "<span class=\"math-inline\">\\(\\1\\)</span>")
  end
  
  defp load_syllabus_topics do
    from(s in Syllabus,
      where: is_nil(s.parent_topic_id),  # Only root topics for now
      order_by: [asc: s.order_index, asc: s.topic]
    )
    |> Repo.all()
  end
end