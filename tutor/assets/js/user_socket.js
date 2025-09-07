// WebSocket client for Project Bloom tutoring sessions
import {Socket} from "phoenix"

// Initialize socket connection
let socket = new Socket("/socket", {
  params: {
    // For development - in production this would be a proper auth token
    token: "user:guest_user"
  }
})

// Optional: Add connection lifecycle callbacks
socket.onOpen(() => console.log("Connected to tutor server"))
socket.onError((error) => console.log("Connection error:", error))
socket.onClose(() => console.log("Disconnected from tutor server"))

// Connect to server
socket.connect()

// Session channel management
class TutorSession {
  constructor(sessionId) {
    this.sessionId = sessionId
    this.channel = null
    this.messageHandlers = new Map()
    this.reconnectTimer = null
  }

  connect() {
    if (this.channel && this.channel.isJoined()) {
      console.log("Already connected to session")
      return Promise.resolve()
    }

    this.channel = socket.channel(`session:${this.sessionId}`, {})

    // Set up message handlers
    this.setupMessageHandlers()

    // Join the channel
    return new Promise((resolve, reject) => {
      this.channel.join()
        .receive("ok", (resp) => {
          console.log("Joined session successfully", resp)
          this.clearReconnectTimer()
          resolve(resp)
        })
        .receive("error", (resp) => {
          console.error("Unable to join session", resp)
          reject(resp)
        })
        .receive("timeout", () => {
          console.error("Session join timeout")
          reject(new Error("timeout"))
        })
    })
  }

  setupMessageHandlers() {
    if (!this.channel) return

    // Handle tutor responses
    this.channel.on("tutor_response", (payload) => {
      console.log("Tutor response:", payload)
      this.emit('tutor_response', payload)
    })

    // Handle state changes
    this.channel.on("state_change", (payload) => {
      console.log("Session state changed:", payload)
      this.emit('state_change', payload)
    })

    // Handle errors
    this.channel.on("error", (payload) => {
      console.error("Session error:", payload)
      this.emit('error', payload)
    })

    // Handle disconnections and implement reconnection logic
    this.channel.onError(() => {
      console.error("Channel error occurred")
      this.scheduleReconnect()
    })

    this.channel.onClose(() => {
      console.log("Channel closed")
      this.scheduleReconnect()
    })
  }

  scheduleReconnect() {
    if (this.reconnectTimer) return

    console.log("Scheduling reconnection in 5 seconds...")
    this.reconnectTimer = setTimeout(() => {
      console.log("Attempting to reconnect...")
      this.reconnectTimer = null
      this.connect().catch(error => {
        console.error("Reconnection failed:", error)
        // Schedule another attempt
        this.scheduleReconnect()
      })
    }, 5000)
  }

  clearReconnectTimer() {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer)
      this.reconnectTimer = null
    }
  }

  sendMessage(content) {
    if (!this.channel || !this.channel.isJoined()) {
      console.error("Cannot send message: not connected to session")
      return Promise.reject(new Error("not_connected"))
    }

    return new Promise((resolve, reject) => {
      this.channel.push("user_message", { content })
        .receive("ok", resolve)
        .receive("error", reject)
        .receive("timeout", () => reject(new Error("timeout")))
    })
  }

  ping() {
    if (!this.channel || !this.channel.isJoined()) {
      return Promise.reject(new Error("not_connected"))
    }

    return new Promise((resolve, reject) => {
      this.channel.push("ping", {})
        .receive("ok", () => resolve("pong"))
        .receive("error", reject)
        .receive("timeout", () => reject(new Error("timeout")))
    })
  }

  disconnect() {
    this.clearReconnectTimer()
    if (this.channel) {
      this.channel.leave()
      this.channel = null
    }
  }

  // Event emitter pattern for handling messages
  on(event, handler) {
    if (!this.messageHandlers.has(event)) {
      this.messageHandlers.set(event, [])
    }
    this.messageHandlers.get(event).push(handler)
  }

  off(event, handler) {
    if (this.messageHandlers.has(event)) {
      const handlers = this.messageHandlers.get(event)
      const index = handlers.indexOf(handler)
      if (index !== -1) {
        handlers.splice(index, 1)
      }
    }
  }

  emit(event, data) {
    if (this.messageHandlers.has(event)) {
      this.messageHandlers.get(event).forEach(handler => {
        try {
          handler(data)
        } catch (error) {
          console.error("Error in message handler:", error)
        }
      })
    }
  }
}

// Export for use in other modules
window.TutorSession = TutorSession
window.tutorSocket = socket

export { socket, TutorSession }