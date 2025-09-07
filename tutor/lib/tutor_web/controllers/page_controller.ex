defmodule TutorWeb.PageController do
  use TutorWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def chat(conn, _params) do
    # Chat page for testing WebSocket connections
    render(conn, :chat, layout: false)
  end
end
