defmodule TutorWeb.UserSocketTest do
  use ExUnit.Case, async: true
  
  alias TutorWeb.UserSocket
  
  describe "connect/3" do
    test "connects with valid token" do
      params = %{"token" => "user:123"}
      connect_info = %{}
      
      {:ok, socket} = UserSocket.connect(params, %Phoenix.Socket{}, connect_info)
      
      assert socket.assigns.user_id == "123"
    end
    
    test "connects without token in development" do
      params = %{}
      connect_info = %{}
      
      {:ok, socket} = UserSocket.connect(params, %Phoenix.Socket{}, connect_info)
      
      assert socket.assigns.user_id == "guest_user"
    end
    
    test "rejects invalid token format" do
      params = %{"token" => "invalid_format"}
      connect_info = %{}
      
      assert UserSocket.connect(params, %Phoenix.Socket{}, connect_info) == :error
    end
  end
  
  describe "id/1" do
    test "returns socket id based on user_id" do
      socket = %Phoenix.Socket{assigns: %{user_id: "123"}}
      
      assert UserSocket.id(socket) == "user_socket:123"
    end
  end
end