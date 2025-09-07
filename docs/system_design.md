## System Design: Interactive Pedagogical LLM Platform

### 1. Introduction

#### 1.1. Overview

This document outlines the system architecture and technical design for an interactive, stateful pedagogical platform. The application will facilitate a one-on-one learning session between a user and a Large Language Model (LLM), guiding the user through a structured syllabus. The core of the system is designed to be a robust, real-time, and conversational experience, capable of managing the unique context and pedagogical state of numerous concurrent user sessions.

#### 1.2. Goals & Objectives

* **Stateful Interaction:** Maintain the complete context of each user's session, including chat history, current syllabus position, and pedagogical state.
* **Real-Time Responsiveness:** Utilize a low-latency, bidirectional communication channel to create a fluid, conversational user experience.
* **Pedagogical Logic:** Implement a formal state machine to manage the flow of the learning session, moving between states such as exposition, questioning, and error remediation.
* **Extensible Tooling:** Integrate with external services, primarily LLM-based tools, for functions like answer validation and common error analysis.
* **Fault Tolerance & Scalability:** Build a resilient system where the failure of a single user session does not impact the wider application, and which is architected to scale efficiently.

---

### 2. System Architecture

#### 2.1. High-Level Overview

The application is designed as a distributed system composed of several distinct layers, with Elixir and the OTP framework at its core. This choice is driven by the need for high concurrency and robust state management.[1]

The primary components are:

* **Client (Web Browser):** The user-facing interface, responsible for rendering the conversation and capturing user input.
* **Web Layer (Phoenix Framework):** Serves the client application and manages persistent, real-time communication using Phoenix Channels (WebSockets).
* **Session Management Core (OTP Application):** The heart of the backend. This layer is responsible for managing the lifecycle and state of every active user session.
* **Tooling Service:** An abstraction layer that communicates with external services, such as LLM APIs for answer checking or database lookups for student records.
* **Persistence Layer (PostgreSQL Database):** Provides long-term storage for user data, syllabus content, and conversation histories.

```mermaid
graph LR
    subgraph "User Interface"
        Client[Client<br/>(Web Browser)]
    end

    subgraph "Backend System (Elixir/OTP)"
        Web[Web Layer<br/>(Phoenix Framework)]
        Core[Session Management Core<br/>(OTP Application)]
        Tools[Tooling Service]
        DB[(Persistence<br/>PostgreSQL)]

        Client -- WebSockets/HTTP --> Web
        Web -- GenServer.cast --> Core
        Core -- async task --> Tools
        Tools -- query --> DB
        DB -- result --> Tools
        Tools -- result --> Core
        Core -- push --> Web
        Web -- WebSocket push --> Client
    end

    subgraph "External Services"
        LLM[LLM APIs]
        Tools -- API call --> LLM
        LLM -- response --> Tools
    end
```

#### 2.2. Request Flow

A typical user interaction follows this sequence:

1. The user sends a message through the client interface.
2. The message is pushed over a persistent WebSocket connection to the corresponding Phoenix Channel process on the server.
3. The Channel process, holding the user's unique ID, uses a Registry to locate the user's dedicated SessionServer process.[4]
4. An asynchronous message (GenServer.cast) is sent to the SessionServer containing the user's input.[5] The Channel process returns immediately, keeping the UI responsive.
5. The SessionServer processes the message according to its current pedagogical state (e.g., if awaiting an answer, it triggers an "check answer" tool).
6. The SessionServer delegates the long-running tool execution to a separate, monitored Task process to avoid blocking.[1]
7. Upon completion, the Task sends its result back to the SessionServer.
8. The SessionServer updates its state, formulates a response, and pushes the new message back to the user's Phoenix Channel process.
9. The Channel process broadcasts the message over the WebSocket to the client, where it is rendered in the UI.

---

### 3. Component Deep Dive

#### 3.1. Web Layer (Phoenix Framework)

The Phoenix web framework serves as the primary entry point for all client communication.

* **Phoenix Channels:** Channels provide the real-time, bidirectional communication necessary for a chat-based application. Each user connection will be managed by a dedicated Channel process.
* **Session Lifecycle Management:** The Channel process is responsible for orchestrating the lifecycle of a user's session. Upon a user's successful connection (join), the Channel will request the SessionSupervisor to start a new SessionServer process. Upon disconnection (terminate), it will trigger a graceful shutdown of that same process.

#### 3.2. Session Management Core (OTP Application)

This is the stateful core of the application, built on OTP principles to ensure robustness and concurrency. It consists of four key modules:

* **SessionServer (GenServer):** A dedicated GenServer process is spawned for each active user session. This process holds the entire state of a single session in memory—including conversation history, pedagogical context, and the current question—and implements the core pedagogical state machine logic.
* **SessionSupervisor (DynamicSupervisor):** A DynamicSupervisor is used to start and stop SessionServer processes on demand.[8] It is configured with a
:one_for_one restart strategy, ensuring that the failure of one user's session process is isolated and does not affect any others.[8]
* **SessionRegistry (Registry):** Provides a fast, scalable, and safe mechanism for mapping a stable user ID to its ephemeral process ID (PID).[4] This allows any part of the application to communicate with a user's session without needing to track its PID directly. Using a
Registry avoids the dangerous anti-pattern of converting user input into atoms for process naming.[6]
* **ToolExecutor (Task.Supervisor):** A supervised pool of Task processes for executing long-running, asynchronous work.[8] This decouples the responsive
SessionServer from slow external dependencies like LLM API calls.

#### 3.3. Tooling Service

This is a standard Elixir module that acts as a functional boundary between the session logic and external dependencies. It will expose a clear API, such as:

* Tools.check_answer(question, answer)
* Tools.label_common_errors(text)
* Tools.get_student_record(user_id)

Internally, these functions will handle the specifics of formatting API requests, communicating with HTTP clients (like Tesla or Req), and parsing responses. The SessionServer will invoke these functions via the ToolExecutor to ensure non-blocking execution.

#### 3.4. Persistence Layer

* **Technology:** A PostgreSQL database, accessed via Elixir's Ecto library.
* **Schema:** The database will store long-term data that must survive application restarts. Key tables will include:
  * users: Stores user authentication and profile information.
  * syllabuses: Defines the structure and content of learning modules.
  * session_histories: Persists the full conversation log and final state of completed user sessions for auditing and analytics.

---

### 4. Data Model & State Management

#### 4.1. Pedagogical State Machine

The SessionServer implements a formal finite state machine to manage the flow of each learning session. Each state represents a distinct mode of conversation, with transitions triggered by events like user input or asynchronous tool results.

##### Core Pedagogical States

* **`:initializing`** - Entry point for new sessions
  * Actions: Load user profile/progress, fetch syllabus, set pedagogical guidance
  * Transitions: → `:exposition` upon successful initialization

* **`:exposition`** - Primary instructional state ("lecture mode")
  * Actions: Deliver instructional content, handle clarifying questions
  * Transitions: → `:setting_question` when instruction complete

* **`:setting_question`** - Transitional state for question formulation
  * Actions: Select and present next question from syllabus
  * Transitions: → `:awaiting_answer` immediately after question sent

* **`:awaiting_answer`** - Passive listening state
  * Actions: Wait for user message
  * Transitions: → `:evaluating_answer` when message received

* **`:evaluating_answer`** - Critical transient state for processing submissions
  * Actions: Trigger async tools (check_answer, check_for_common_errors)
  * Acts as lock to prevent race conditions from rapid user messages
  * GenServer waits for :DOWN message from Task process
  * Transitions:
    * → `:providing_feedback_correct` if answer correct
    * → `:remediating_known_error` if matches known error pattern
    * → `:remediating_unknown_error` if incorrect without pattern match

* **`:providing_feedback_correct`** - Positive reinforcement state
  * Actions: Congratulate user, update mastery tracking
  * Transitions: → `:exposition` for next topic OR → `:session_complete` if syllabus finished

* **`:remediating_known_error`** - Targeted corrective feedback
  * Actions: Explain specific error pattern, provide tailored hints
  * Transitions: → `:awaiting_answer` to retry same question

* **`:remediating_unknown_error`** - General Socratic guidance
  * Actions: Provide subtle hints, rephrase question
  * Transitions: → `:guiding_student` for detailed sub-dialogue

* **`:guiding_student`** - Conversational sub-loop for stuck students
  * Actions: Break down problem, offer successive hints, respond to reasoning
  * Transitions: → `:awaiting_answer` when ready to retry

* **`:session_complete`** - Terminal state
  * Actions: Provide session summary, persist final state
  * Transitions: None (GenServer terminates)

##### State Flow Patterns

**Primary Learning Loop (Happy Path):**
```
initializing → exposition → setting_question → awaiting_answer → 
evaluating_answer → providing_feedback_correct → exposition (loop)
```

**Remediation Loop (Known Error):**
```
evaluating_answer → remediating_known_error → awaiting_answer (retry)
```

**Guidance Loop (Unknown Error):**
```
evaluating_answer → remediating_unknown_error → guiding_student → 
awaiting_answer (retry with support)
```

#### 4.2. State Storage

The system manages two distinct types of state:

* **Ephemeral State (In-Memory):** This is the live state of an active user session, managed entirely within its dedicated SessionServer process. It is structured as a map containing fields like user_id, pedagogical_state (current FSM state), conversation_history, syllabus_context, and current_question. This in-memory model provides extremely fast read/write access, which is critical for the real-time nature of the application.
* **Persistent State (Database):** This is the long-term, durable state. The SessionServer is responsible for ensuring that critical data is persisted. This will occur at key lifecycle events, primarily during a graceful shutdown (via the terminate/2 callback).[2] This ensures the full conversation history is saved upon session completion. For very long-running sessions, a periodic persistence mechanism can be added to save snapshots and prevent data loss in the event of an unexpected crash.

---

### 5. Fault Tolerance and Scalability

#### 5.1. Fault Tolerance

The application's resilience is a direct result of adopting OTP's "let it crash" philosophy, implemented via supervision trees.[10]

* **Process Isolation:** Each user session is an isolated process. A programming error or unexpected condition that causes one SessionServer to crash will have zero impact on other active sessions.
* **Automatic Recovery:** The SessionSupervisor monitors all child SessionServer processes. If a process terminates abnormally, the supervisor will, according to its :transient restart strategy, automatically start a new, clean process to take its place.[8] This self-healing capability is a core feature of the architecture.

#### 5.2. Scalability

* **Vertical Scalability:** The Erlang VM (BEAM) is designed to utilize all available CPU cores efficiently. The process-based architecture allows the system to handle tens of thousands of concurrent sessions on a single node by distributing the load across schedulers.
* **Horizontal Scalability (Future Considerations):** The current design, using a local Registry, is optimized for a single-node deployment. To scale across multiple nodes, the architecture would need to evolve. The most idiomatic path involves replacing the local Registry with a distributed alternative like the Horde library, which provides a distributed Registry and DynamicSupervisor.[12] This would allow a user's request to be routed to the correct process, regardless of which node in the cluster it resides on.

---

### 6. Conclusion

This design leverages the unique strengths of Elixir, Phoenix, and OTP to build a highly concurrent, stateful, and fault-tolerant application. By isolating each user session into a supervised GenServer process, we create a system that is both resilient to individual failures and capable of scaling to a large number of simultaneous users. The clear separation of concerns between the web layer, the stateful session core, and external tooling services results in a maintainable and extensible architecture, providing a solid foundation for the Interactive Pedagogical LLM Platform.

#### Works cited

1. Mastering GenServer for Enhanced Elixir Applications - Curiosum, accessed on September 7, 2025, [https://curiosum.com/blog/what-is-elixir-genserver](https://curiosum.com/blog/what-is-elixir-genserver)
2. Elixir/OTP : Basics of GenServer - Medium, accessed on September 7, 2025, [https://medium.com/elemental-elixir/elixir-otp-basics-of-genserver-18ec78cc3148](https://medium.com/elemental-elixir/elixir-otp-basics-of-genserver-18ec78cc3148)
3. Elixir GenServers: Overview and Tutorial - Scout APM, accessed on September 7, 2025, [https://www.scoutapm.com/blog/elixirs-genservers-overview-and-tutorial](https://www.scoutapm.com/blog/elixirs-genservers-overview-and-tutorial)
4. GenServer — Elixir v1.12.3 - HexDocs, accessed on September 7, 2025, [https://hexdocs.pm/elixir/1.12/GenServer.html](https://hexdocs.pm/elixir/1.12/GenServer.html)
5. Client-server communication with GenServer — Elixir v1.18.4 - HexDocs, accessed on September 7, 2025, [https://hexdocs.pm/elixir/genservers.html](https://hexdocs.pm/elixir/genservers.html)
6. GenServer - Elixir, accessed on September 7, 2025, [http://elixir-br.github.io/getting-started/mix-otp/genserver.html](http://elixir-br.github.io/getting-started/mix-otp/genserver.html)
7. Learning Elixir's GenServer with a real-world example - DEV Community, accessed on September 7, 2025, [https://dev.to/_areichert/learning-elixir-s-genserver-with-a-real-world-example-5fef](https://dev.to/_areichert/learning-elixir-s-genserver-with-a-real-world-example-5fef)
8. OTP Supervisors - Elixir School, accessed on September 7, 2025, [https://elixirschool.com/en/lessons/advanced/otp_supervisors](https://elixirschool.com/en/lessons/advanced/otp_supervisors)
9. Exploring Elixir's OTP Supervision Trees - CloudDevs, accessed on September 7, 2025, [https://clouddevs.com/elixir/otp-supervision-trees/](https://clouddevs.com/elixir/otp-supervision-trees/)
10. Overview — Erlang System Documentation v28.0.2 - Erlang/OTP, accessed on September 7, 2025, [https://www.erlang.org/doc/system/design_principles.html](https://www.erlang.org/doc/system/design_principles.html)
11. Erlang - Elixir: What is a supervision tree? - Stack Overflow, accessed on September 7, 2025, [https://stackoverflow.com/questions/46554449/erlang-elixir-what-is-a-supervision-tree](https://stackoverflow.com/questions/46554449/erlang-elixir-what-is-a-supervision-tree)
12. Managing Distributed State with GenServers in Phoenix and Elixir | AppSignal Blog, accessed on September 7, 2025, [https://blog.appsignal.com/2024/10/29/managing-distributed-state-with-genservers-in-phoenix-and-elixir.html](https://blog.appsignal.com/2024/10/29/managing-distributed-state-with-genservers-in-phoenix-and-elixir.html)
