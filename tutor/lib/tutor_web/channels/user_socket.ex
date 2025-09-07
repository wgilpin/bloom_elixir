defmodule TutorWeb.UserSocket do
  use Phoenix.Socket

  # A Socket handler
  #
  # It's possible to control the websocket connection and
  # assign values that can be accessed by your channel topics.

  ## Channels
  # Uncomment the following line to define a "room:*" topic
  # pointing to the `TutorWeb.RoomChannel`:
  #
  # channel "room:*", TutorWeb.RoomChannel
  channel "session:*", TutorWeb.SessionChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error` or `{:error, term}`.
  def connect(%{"token" => token}, socket, _connect_info) do
    # Verify user token and assign user_id
    case verify_user_token(token) do
      {:ok, user_id} ->
        socket = assign(socket, :user_id, user_id)
        {:ok, socket}
      {:error, _reason} ->
        :error
    end
  end

  # Allow connection without token for now (development mode)
  def connect(_params, socket, _connect_info) do
    # For development - assign a default user_id
    # In production, this should require authentication
    socket = assign(socket, :user_id, "guest_user")
    {:ok, socket}
  end

  # Socket IDs are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Elixir.TutorWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"

  # Private functions

  defp verify_user_token(token) do
    # TODO: Implement actual token verification
    # For now, just extract user_id from token
    case String.split(token, ":") do
      ["user", user_id] -> {:ok, user_id}
      _ -> {:error, :invalid_token}
    end
  end
end