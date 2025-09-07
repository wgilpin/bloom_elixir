# A Technical Design for a Stateful LLM Interaction Server in Elixir

## I. Architectural Blueprint for the LLM Session Server

This document presents a comprehensive architectural design for a stateful component, implemented as an Elixir GenServer, to manage interactive, pedagogical sessions between a user and a Large Language Model (LLM). The design prioritizes robustness, scalability, and maintainability by adhering to the principles of the Open Telecom Platform (OTP).

### 1.1 Rationale for GenServer

The GenServer behavior is the cornerstone of this architecture, selected for its inherent suitability for managing stateful, concurrent server processes.[1] Each user's learning session is a long-running, stateful interaction that must handle sequential and concurrent requests. The

GenServer provides a standardized, battle-tested abstraction for this exact use case, encapsulating the state, the logic for state transitions, and the communication protocol within a single, isolated process.[3]

This choice is deliberate when contrasted with other OTP abstractions. An Agent is designed for managing simple, shared state via functional updates but lacks the facility for the complex, multi-clause logic required by our pedagogical state machine.[4] A

Task is appropriate for executing one-off, asynchronous functions but is not intended for maintaining a persistent state across multiple interactions.[1] The core of our requirement is not merely to run a function asynchronously but to model the evolving runtime characteristics of a user's session—its history, its current pedagogical mode, and its pending operations. OTP design principles dictate that processes, and specifically

GenServers, are the correct tool for modeling such runtime behavior, whereas modules and functions are used for code organization.[5] Consequently, each

SessionServer process will be a concrete, in-memory representation of a single, active user session.

### 1.2 The Core Architectural Components

To achieve a clean separation of concerns and a resilient system, the architecture is composed of four distinct, collaborating components. This modularity is fundamental to OTP design and is critical for building testable, maintainable, and scalable applications.[7]

* **SessionServer**: This is the GenServer module at the heart of the design. An instance of this process is spawned for each active user session. It is solely responsible for managing the session's internal state, executing the pedagogical state machine, and coordinating with external tools.
* **SessionSupervisor**: A DynamicSupervisor is used to manage the lifecycle of SessionServer processes. Unlike a standard Supervisor which starts a static list of children, a DynamicSupervisor allows for SessionServer processes to be started and stopped on-demand at runtime, which is essential as users connect to and disconnect from the system.[8]
* **SessionRegistry**: An instance of Elixir's Registry module provides a crucial service: mapping a stable user identifier (e.g., a database ID) to the volatile process identifier (PID) of their corresponding SessionServer. This acts as a decoupled service discovery mechanism, allowing other parts of the application to communicate with a user's session without needing to know its physical process ID.
* **ToolExecutor**: This is a conceptual module, likely backed by a Task.Supervisor, responsible for managing the execution of external "tools." These tools include long-running operations like LLM API calls or database queries. By isolating this functionality, the SessionServer can delegate asynchronous work without cluttering its core state management logic.

The typical flow of a user interaction proceeds as follows: A client request, originating from a transport layer like a Phoenix Channel, is directed to the SessionRegistry using the user's stable ID. The Registry transparently forwards the message to the correct SessionServer process. The SessionServer processes the message, which may involve delegating a long-running task to the ToolExecutor. Upon completion of the task, the SessionServer updates its state and pushes a response back to the client.

### 1.3 Implications of the Architectural Design

The decision to separate state management (SessionServer), process lifecycle (SessionSupervisor), process discovery (SessionRegistry), and external interactions (ToolExecutor) is a direct application of OTP's fault-tolerance philosophy.[9] This structure yields a highly robust and decoupled system.

The requirement for a unique process per user session immediately rules out a static supervision tree, which manages a fixed set of children defined at compile time.[11] User sessions are dynamic by nature. This leads directly to the selection of

DynamicSupervisor, a behavior designed specifically for starting and stopping supervised children at runtime.[8]

Once a process is dynamically started, a new problem emerges: how can other processes find and communicate with it? The PID assigned to a process is ephemeral; it changes if the process is restarted. Relying on PIDs directly would create a brittle system. A common pattern is to register a process with a name. However, using atoms for names derived from user input is a critical vulnerability, as atoms in the Erlang VM are not garbage-collected. An attacker could exhaust system memory by creating a large number of unique sessions.[12]

This chain of constraints logically leads to the use of a dedicated process registry. Elixir's Registry module is the modern, scalable, and safe solution for this problem on a single node. It allows arbitrary terms (like a user's integer ID) to be mapped to PIDs, providing a stable "address" for a dynamic resource.[5] This architectural pattern—a

DynamicSupervisor creating workers that register themselves in a Registry—is a canonical and powerful OTP idiom for managing pools of dynamic, named processes. It creates a system where components have single, well-defined responsibilities, a cornerstone of fault-tolerant design.

## II. The Anatomy of Session State

The design of the GenServer's internal state is paramount, as it defines the boundaries of the component's capabilities. A well-structured state enables complex logic, while a poorly designed one leads to bugs and unmaintainable code. The state will be implemented as an Elixir map, which provides a flexible and explicit structure. This state is initialized within the init/1 callback, which is invoked when the GenServer process is first started by its supervisor.[1] The arguments passed to

GenServer.start_link/3, such as the user's ID and initial syllabus context, are received by init/1 to establish this initial state.[2]

### 2.1 State Structure Definition

The following table provides a formal specification of the SessionServer's state map. This definition serves as a contract, ensuring that all necessary data for managing a pedagogical session is explicitly tracked.

| Field | Elixir Type | Description |
| :--- | :--- | :--- |
| `user_id` | `integer` or `string` | The unique, stable identifier for the user. This is used for registration and persistence. |
| `pedagogical_state` | `atom` | The current state of the pedagogical Finite State Machine (FSM), such as `:exposition`, `:awaiting_answer`, or `:remediating_known_error`. |
| `conversation_history` | `list(map())` | An ordered log of all messages exchanged between the user and the LLM. Each entry should contain the message content, speaker role (`:user` or `:assistant`), and a timestamp. |
| `pedagogical_context` | `map()` | General guidance for the LLM that persists across interactions, such as the desired tone, persona, and high-level learning objectives. |
| `syllabus_context` | `map()` | Data related to the user's current position in the syllabus, including the current topic, learning materials, and a queue of questions to be asked. |
| `current_question` | `map()` or `nil` | The full details of the question the user is currently expected to answer, including the question text, expected answer format, and any associated metadata. |
| `pending_tool_calls` | `map()` | A map where keys are monitor references and values are metadata about in-flight asynchronous tool calls. Example value: `%{tool: :check_answer, started_at: ~U[...], from: from}`. |

### 2.2 The Critical Role of pending_tool_calls

Within the state definition, the pending_tool_calls map is the most critical element for building a responsive and robust system. Its purpose is to manage the state of asynchronous operations, such as calls to external LLM services, which are inherently slow and unpredictable.

A naive implementation might use a synchronous GenServer.call to invoke an external tool. This is a severe anti-pattern for long-running operations. The GenServer process executes its code in a single-threaded message loop; a blocking call would freeze the entire process, making it unable to respond to any other messages—including shutdown commands from its supervisor or cancellation requests from the user. This would lead to cascading timeouts and an unresponsive system.[4]

Conversely, an asynchronous GenServer.cast is a "fire-and-forget" mechanism. While it would not block the SessionServer, it provides no way for the server to receive the result of the operation.[4] The

SessionServer needs to know when the tool has finished and whether it succeeded or failed.

The correct pattern, which will be detailed in Section V, involves delegating the work to a separate process (a Task) and then monitoring that process. The pending_tool_calls map is the stateful component that makes this pattern work. When a tool is invoked, the SessionServer creates a Task, monitors it, and stores the unique monitor reference as a key in this map. The value associated with that key is a map of context: what tool was called, when it was started, and, crucially, who needs to be notified upon completion. The SessionServer can then immediately return {:noreply,...} and continue processing other messages.

When the Task completes, the Erlang VM sends a :DOWN message to the SessionServer's mailbox. This message, handled in the handle_info/2 callback, contains the same unique monitor reference.[4] The server uses this reference to look up the context in

pending_tool_calls, allowing it to correlate the result with the original request and take the appropriate action. This mechanism effectively decouples the initiation of an asynchronous operation from the handling of its result, which is the foundation of a non-blocking, message-driven OTP server.

## III. The Client API: A Contract for Interaction

A well-designed GenServer separates its public client API from its internal server callbacks.[4] This creates a clean, stable contract for how other parts of the system can interact with a

SessionServer, abstracting away the complexities of its internal state machine. This section defines this public interface.

### 3.1 API Design Principles

The design of the client API adheres to two key principles derived from established OTP best practices.

First, the choice between synchronous (call) and asynchronous (cast) communication is deliberate for each function. A call is used when the client requires an immediate, synchronous response, such as retrieving data or confirming that an operation has been completed. This synchronous nature also provides a form of back-pressure; the client cannot overwhelm the server with requests faster than it can process them.[4] A

cast is used for operations that may initiate long-running, asynchronous work where the client does not need to wait for the final outcome. This is ideal for event-style messages that trigger state transitions.[4]

Second, the message protocol for requests sent to the server is standardized using tuples. The first element of the tuple is an atom that identifies the request type, and subsequent elements are the arguments for that request (e.g., {:user_message, "my answer"}). This is a common and extensible pattern in the Elixir ecosystem.[4]

### 3.2 API Function Specification

The following table specifies the public functions that constitute the client API for the SessionServer.

| Function Signature | Type | Description |
| :--- | :--- | :--- |
| `start_link(init_args)` | Synchronous | Starts a new SessionServer process and links it to the caller (typically the SessionSupervisor). The `init_args` map contains initial context like `user_id` and `syllabus_context`. |
| `handle_user_message(server, message)` | `cast` | Submits a new message from the user to the session. This is an asynchronous operation, as processing the message will likely trigger a slow LLM tool call. The `server` argument can be a PID or a `via` tuple for the Registry. |
| `get_full_state(server)` | `call` | Synchronously retrieves the entire current state map of the session. This is primarily intended for debugging and administrative introspection. |
| `force_remediation(server, error_type)` | `cast` | Allows an external system (e.g., an admin dashboard) to manually trigger a specific remediation flow within the session's state machine. |
| `shutdown(server)` | `cast` | Sends a message to the SessionServer to perform a graceful shutdown, which may include persisting its final state before terminating. |

### 3.3 Implications of Asynchronous Message Handling

The decision to implement handle_user_message/2 as a cast is a critical choice that directly impacts user experience and system design. When a user submits a message through the interface (e.g., a web browser), the client-side process (such as a Phoenix Channel) can call handle_user_message and receive an immediate :ok return. This allows the UI to feel instantaneous, confirming to the user that their message has been received without waiting for the full round-trip to the LLM, which could take several seconds.

However, this asynchronous design introduces a new challenge. If the client's request handler returns immediately, how does the final response from the LLM get delivered back to the user's browser? The SessionServer must now have a mechanism for initiating outbound communication. This reveals a hidden requirement: the communication is not purely client-to-server.

The solution is to include the client's identity in the message payload. For example, the call would become handle_user_message(server, message, client_pid). The SessionServer would then store this client_pid (e.g., the PID of the user's Phoenix Channel process) in its state. When the asynchronous LLM tool eventually completes and the SessionServer has formulated a response, it can use this stored PID to push the message directly back to the correct client process. This transforms the interaction from a simple request/response model into a more flexible, bidirectional message-passing relationship, which is a natural fit for the process-oriented paradigm of the BEAM.

## IV. Server Implementation: The State Machine Logic

This section details the internal implementation of the GenServer callbacks, which contain the core logic of the pedagogical session. The server's primary responsibility is to act as a Finite State Machine (FSM), transitioning between well-defined pedagogical states in response to internal and external messages.

### 4.1 The init/1 and terminate/2 Callbacks

The lifecycle of the GenServer is bookended by the init/1 and terminate/2 callbacks.

* **init/1**: This function is called exactly once when the process is started by GenServer.start_link/3.[2] Its role is to initialize the server's state. It receives the arguments passed to
start_link and must return {:ok, initial_state} on success.[1] For the
SessionServer, this involves setting up the initial state map by loading the user's record, fetching the relevant syllabus context, and setting the initial pedagogical_state to a starting value like :exposition. It is also the ideal place to perform process registration with the SessionRegistry.
* **terminate/2**: This callback is invoked just before the process exits. It provides a hook for graceful shutdown and cleanup. For this callback to be reliably called when the parent supervisor is shutting down, the process should trap exits by calling Process.flag(:trap_exit, true) during initialization.[13] A primary use case for
terminate/2 in the SessionServer is to persist the final conversation history and state to a database, ensuring no data is lost when a session ends.[2]

### 4.2 Handling Client Messages (handle_cast/handle_call)

The handle_call/3 and handle_cast/2 callbacks are the workhorses of the GenServer, processing synchronous and asynchronous messages, respectively.[12] The central piece of logic will be in

handle_cast({:user_message, message}, state), which drives the FSM. Its implementation will typically be a case statement that dispatches based on the current value of state.pedagogical_state.

For example:

* If the state is :awaiting_answer, a {:user_message,...} is interpreted as the user's answer to a question. The server will add the message to the conversation history and trigger the :check_answer tool.
* If the state is :exposition, the same message might be interpreted as a clarifying question from the user, triggering a different LLM tool designed for explanation.

After processing the message and potentially initiating an asynchronous task, the function will update the state map and return a {:noreply, new_state} tuple, signaling that no synchronous reply is being sent and providing the GenServer machinery with the updated state for the next message.[12]

### 4.3 The Pedagogical State Machine

To manage the complexity of the pedagogical interaction, the logic should be formally defined as a state transition matrix. This provides an unambiguous specification of the FSM's behavior, mapping every combination of the current state and an incoming event to a set of actions and a resulting new state. This formalization is a powerful design tool that helps prevent bugs and undefined behavior.

The following table provides an excerpt of such a matrix:

| Current State | Event | Actions | Next State |
| :--- | :--- | :--- | :--- |
| `:exposition` | `{:user_message, msg}` | 1. Add `msg` to `conversation_history`. 2. Start `:clarify_concept` tool with `msg`. | `:awaiting_tool_result` |
| `:awaiting_answer` | `{:user_message, ans}` | 1. Add `ans` to `conversation_history`. 2. Start `:check_answer` tool with `ans` and `current_question`. | `:awaiting_tool_result` |
| `:awaiting_tool_result` | `{:tool_result, {:ok, res}}` | 1. Process `res` based on original tool. 2. Formulate next response/question. 3. Send response to user. 4. Update `syllabus_context`. | (Depends on result, e.g., `:setting_question` or `:remediating_known_error`) |
| `:awaiting_tool_result` | `{:tool_result, {:error, reason}}` | 1. Log the error `reason`. 2. Formulate an error message for the user. 3. Send error message to user. | (Depends on error, e.g., `:error_state` or back to previous state) |
| `:awaiting_tool_result` | `{:user_message, msg}` | 1. Add `msg` to `conversation_history`. 2. Send a "Please wait, I'm still processing your previous message" response to the user. | `:awaiting_tool_result` |

### 4.4 The Necessity of a Transient State

The state transition matrix highlights a critical design element: the need for a transient "locking" state, here named :awaiting_tool_result. This state is essential for preventing race conditions and handling user input gracefully while the system is busy.

Consider the scenario where the server is in the :awaiting_answer state. It receives the user's answer, starts the slow :check_answer tool, and prepares to wait for the result. If the user quickly sends a second message before the tool has finished, a potential race condition occurs. If the server were to remain in the :awaiting_answer state, it would incorrectly process this second message as another answer to the same question, possibly launching a second, conflicting tool call and leading to an inconsistent state.

To prevent this, the server must atomically transition to an intermediate state like :awaiting_tool_result *immediately* after initiating the asynchronous tool. The state transition matrix formally defines the behavior for this state. As shown in the table, any new {:user_message,...} event received while in :awaiting_tool_result is handled differently—it does not trigger a new tool call but instead results in a polite message to the user, preserving the integrity of the ongoing operation. This use of an explicit transient state is a fundamental pattern for building robust FSMs that interact with asynchronous services.

## V. A Robust Pattern for Asynchronous Tool Execution

This section presents the definitive, non-blocking pattern for interacting with external services like LLMs. This is the most technically nuanced part of the design and is fundamental to creating a responsive, concurrent, and fault-tolerant system that is idiomatic to OTP.

### 5.1 The Problem with Blocking

As previously established, using a synchronous GenServer.call for a long-running operation is a critical anti-pattern. The GenServer behavior processes messages from its mailbox sequentially in a single process. A blocking call will halt this loop, preventing the server from handling any other messages until the call returns. This makes the process unresponsive to other client requests, supervisor commands, or internal system messages, violating the core tenets of a highly available and concurrent system.[4] The entire purpose of the actor model is to avoid such blocking behavior, and the following pattern provides the correct, message-passing alternative.

### 5.2 The Task + monitor Pattern

The robust, non-blocking pattern for asynchronous work involves a precise sequence of operations that leverages fundamental BEAM primitives.

* **Step 1: Starting the Task.** Inside a handle_cast or handle_call callback, instead of invoking the tool's function directly, the work is delegated to a separate process. This is typically done using Task.Supervisor.start_child/2 (if the task needs to be supervised) or Task.async/1 (for a linked task).[1] This immediately spawns a new process to execute the tool's code, freeing the
SessionServer to continue its work.
* **Step 2: Monitoring the Task.** Immediately after starting the task and receiving its PID, the SessionServer calls Process.monitor(task_pid). This is a non-blocking operation that establishes a monitoring relationship. The BEAM now guarantees that if the task_pid terminates for *any reason*, it will send a special :DOWN message to the SessionServer's mailbox. This call returns a unique monitor reference, which is crucial for correlating notifications.[6]
* **Step 3: Updating State.** The SessionServer updates its state by adding the monitor reference to the pending_tool_calls map. The value stored is a map containing all the context needed to process the result later, such as the name of the tool and the from parameter if the original request was a handle_call. The server then returns {:noreply, new_state}, completing its handling of the initial request.
* **Step 4: Handling the Result.** A handle_info/2 callback clause is implemented in the SessionServer to pattern match on the :DOWN message. The shape of this message is {:DOWN, ref, :process, pid, reason}, where ref is the unique monitor reference from Step 2, and reason is :normal for a successful exit or an error tuple if the task crashed.
* **Step 5: Processing and Replying.** Inside this handle_info/2 clause, the server uses the ref to look up the context in its pending_tool_calls state. It then removes the entry from the map to prevent duplicate processing. With the context retrieved, it can process the reason (which contains the return value of the task on normal exit), update its pedagogical state, and formulate a response. If the original request was a call, it can now use the stored from value to send a reply using GenServer.reply(from, result).

### 5.3 Code Example

The following annotated code demonstrates this entire flow.

```elixir
defmodule MyApp.SessionServer do 
  use GenServer 
 
  #... Client API (start_link, handle_user_message, etc.)... 
 

# Step 1: The cast handler initiates the async work 

  @impl true 
  def handle_cast({:user_message, message, client_pid}, state) do 
    # Assume we are in a state that requires checking an answer 
    # Start the tool in a supervised task 
    {:ok, task_pid} = Task.Supervisor.start_child( 
      MyApp.ToolTaskSupervisor, 
      fn -> MyApp.Tools.check_answer(message, state.current_question) end 
    ) 
 
    # Step 2: Monitor the new task process 
    ref = Process.monitor(task_pid) 
 
    # Step 3: Update state with pending tool call information 
    new_pending_calls = Map.put(state.pending_tool_calls, ref, %{ 
      tool: :check_answer, 
      client_pid: client_pid, 
      started_at: DateTime.utc_now() 
    }) 
 
    new_state = 
      %{state | 
        pedagogical_state: :awaiting_tool_result, 
        pending_tool_calls: new_pending_calls 
      } 
 
    {:noreply, new_state} 
  end 
 

# Step 4: The info handler receives the result when the task terminates 

  @impl true 
  def handle_info({:DOWN, ref, :process,_pid, reason}, state) do 
    # Check if this DOWN message corresponds to a tool call we are tracking 
    case Map.pop(state.pending_tool_calls, ref) do 
      {nil, _} -> 
        # Not a ref we are tracking, ignore it 
        {:noreply, state} 
 
      {context, new_pending_calls} -> 
        # Step 5: Process the result 
        new_state = %{state | pending_tool_calls: new_pending_calls} 
        handle_tool_result(reason, context, new_state) 
    end 
  end 
 

# Catch-all for other messages 

  @impl true 
  def handle_info(_msg, state) do 
    {:noreply, state} 
  end 
 

# Helper function to process the result 

  defp handle_tool_result({:normal, result}, context, state) do 
    # Task exited normally, result contains the return value 
    #... logic to process the successful result... 
    #... formulate a response and send it back to the client... 
    MyApp.ClientNotifier.send_response(context.client_pid, response) 
    #... transition to the next pedagogical state... 
    {:noreply, updated_state} 
  end 
 
  defp handle_tool_result(error_reason, context, state) do 
    # Task crashed or exited abnormally 
    #... logic to handle the error... 
    #... inform the client of the failure... 
    MyApp.ClientNotifier.send_error(context.client_pid, "An error occurred.") 
    #... transition to an error state or recover... 
    {:noreply, error_state} 
  end 
end 
```

### 5.4 An Idiomatic and Fault-Tolerant Workflow

This Task + monitor pattern is more than just a technique for avoiding blocking; it represents a fully asynchronous, message-passing workflow that is perfectly idiomatic to OTP. The SessionServer is never blocked and remains responsive to all other messages, including critical supervision commands, throughout the lifecycle of the external call.

Furthermore, this pattern is inherently fault-tolerant. If the Task process crashes due to a bug in the tool code or a network failure, the SessionServer does not crash with it. Instead, it receives a :DOWN message with a non-:normal reason. The handle_tool_result/3 helper function can then handle this failure case explicitly: log the error, transition the FSM to a safe error state, and inform the user that something went wrong. This embodies the "let it crash" philosophy in a controlled manner, isolating failures to small, disposable processes while the core stateful server remains stable and can gracefully recover.

## VI. Supervision and Lifecycle Management

A standalone GenServer process is a single point of failure. To build a resilient application, SessionServer processes must be managed within an OTP supervision tree. This structure ensures fault tolerance by automatically managing the lifecycle of child processes according to predefined strategies.[7]

### 6.1 The Role of the SessionSupervisor

The SessionSupervisor is responsible for starting, monitoring, and, if necessary, restarting SessionServer processes. Given that sessions are created and destroyed dynamically as users interact with the application, a DynamicSupervisor is the appropriate choice.[8]

The supervisor will be configured with the :one_for_one supervision strategy. This means that if a single SessionServer process crashes, only that specific process will be affected and potentially restarted. The failure of one user's session is isolated and will not impact any other active sessions.[8]

The restart strategy for the child SessionServer processes themselves requires careful consideration. The default, :permanent, means the child is always restarted. However, for a user session, this might not be desirable. If a session crashes due to a bug, automatically restarting it might lead to a crash loop. A more suitable strategy is often :transient, which restarts the process only if it terminates abnormally, or :temporary, which never restarts it.[8] For user sessions,

### 6.2 The SessionRegistry

To enable communication with these dynamically supervised processes, a Registry is employed. This provides a fast, in-memory key-value store mapping stable user identifiers to PIDs.[5]

The Registry will be configured with keys: :unique to enforce that only one SessionServer process can be associated with a given user_id at any time. The SessionServer registers itself with this registry as part of its startup sequence. This is achieved idiomatically by using the :name option in GenServer.start_link/3 with a {:via, module, term} tuple. For example: GenServer.start_link(SessionServer, init_args, name: {:via, Registry, {MyApp.SessionRegistry, user_id}}).[5]

With this in place, client code no longer needs to know the PID of a SessionServer. Instead, it sends messages to the stable via tuple, and the Registry handles the PID lookup transparently. For instance: GenServer.cast({:via, Registry, {MyApp.SessionRegistry, user_id}}, {:user_message, "hello"}).

### 6.3 Starting and Stopping Sessions

The lifecycle of a session is managed by an external entity, such as a Phoenix Channel process that handles a user's WebSocket connection.

* **Starting a Session**: When a user connects, the Channel process will request that a new SessionServer be started. It does this by calling DynamicSupervisor.start_child(MyApp.SessionSupervisor, {MyApp.SessionServer, init_args}). The init_args will contain the user_id and other necessary context. The DynamicSupervisor will start the SessionServer, which will in turn register itself in the SessionRegistry.
* **Stopping a Session**: When the user disconnects, the Channel process's terminate/2 callback is the ideal place to clean up the SessionServer. It can find the child process via the supervisor and terminate it gracefully using DynamicSupervisor.terminate_child/2. This ensures that resources are released and the SessionServer's own terminate/2 callback is invoked for final state persistence.

### 6.4 The Power of Decoupling in OTP

The combination of a DynamicSupervisor and a Registry constitutes a powerful and reusable OTP pattern for managing a dynamic pool of named worker processes. This architecture creates a profound decoupling between the *consumer* of a service (the client code sending messages) and the *manager* of that service (the supervisor handling its lifecycle).

The Registry provides a level of indirection, offering a stable, logical address (the user_id) for a volatile, physical resource (the process PID). This abstraction is the key to building a self-healing system. Consider a scenario where a SessionServer crashes due to an unexpected error. If its restart strategy is :transient, the SessionSupervisor will automatically start a new SessionServer process to replace it. This new process, upon initialization, will re-register itself in the Registry under the exact same user_id.

From the perspective of the client code, nothing has changed. It continues to send messages to the same stable via tuple. The Registry seamlessly routes these messages to the new process. The failure and recovery of the underlying server process are completely transparent to the consumer of the service. This is a practical and elegant demonstration of the fault-tolerance and self-healing properties that are the hallmark of the OTP framework.[9]

## VII. Advanced Considerations and Best Practices

A production-ready system requires attention to details beyond the core design, including persistence, resource management, scalability, and observability. This final section addresses these advanced topics to ensure the proposed architecture is robust and enterprise-grade.

### 7.1 State Persistence

The GenServer's state is held in memory, making it vulnerable to loss if the process or the entire node terminates. A persistence strategy is essential for session resumption and data integrity.

* **On-Demand Persistence**: The state can be saved to a persistent store (e.g., a relational database or a key-value store) at critical lifecycle events. The terminate/2 callback is the natural place to save the final state of a session when it ends gracefully.
* **Periodic Persistence**: For long-running sessions, it may be desirable to periodically save snapshots of the state to prevent data loss in case of a crash. This can be implemented using Process.send_after/3 to send a recurring :persist message to the server itself, which is handled in handle_info/2.
* **Resumption**: The init/1 callback can be enhanced to check the database for a previously persisted state for the given user_id. If found, the session can be rehydrated, allowing a user to seamlessly resume their learning session after a disconnection.

### 7.2 Handling Timeouts and Inactivity

A SessionServer process consumes memory and other system resources. It is crucial to clean up sessions that have been abandoned by the user. An inactivity timeout can be implemented using Process.send_after/3.[13]

The pattern works as follows:

1. In init/1 and after handling any user message, start a timer: Process.send_after(self(), :inactivity_timeout, @timeout_ms).
2. Store the timer reference in the GenServer's state.
3. When a new message arrives, cancel the previous timer using Process.cancel_timer(timer_ref) before starting a new one.
4. Implement a handle_info(:inactivity_timeout, state) clause. If this message is received, it means no activity has occurred within the timeout period. The server can then perform cleanup and gracefully shut itself down by returning a {:stop, :normal, state} tuple.

### 7.3 Distributed Elixir

The architecture described thus far, using a local Registry, is designed for a single-node deployment. Scaling horizontally to a multi-node cluster introduces significant new challenges, as process location is no longer transparent.

* **The Challenge**: If a user's request is handled by Node A, their SessionServer will be started on Node A and registered in Node A's local Registry. If their next request is routed by a load balancer to Node B, Node B's Registry will have no knowledge of the process, and the request will fail.
* **Distributed Registries**: The built-in :global registry can register names across a cluster, but it has known scalability bottlenecks and can become a single point of failure.[5] A more robust solution is to use a modern, partition-tolerant library like
Horde, which provides a distributed DynamicSupervisor and Registry.
* **Alternative Strategies**: Other approaches to distribution include:
  * **Sticky Sessions**: Configuring the load balancer to ensure that all requests from a given user are always routed to the same node. This is simpler but reduces fault tolerance.
  * **Distributed PubSub**: Using a tool like Phoenix.PubSub with a PG2 adapter to broadcast requests for a user, allowing the node hosting the process to respond.
  * **CRDTs**: For systems requiring very high availability, state can be managed in a Conflict-free Replicated Data Type (CRDT) library, allowing the session to be active on multiple nodes simultaneously, with state eventually converging.[14]

Architectural foresight is critical here. While starting with a single-node solution is pragmatic, the design must acknowledge the future path to a distributed topology. The choice of a local Registry is a conscious trade-off, and the migration path to a distributed alternative like Horde should be part of the long-term technical roadmap.

### 7.4 Debugging and Introspection

The opaque nature of processes can make debugging challenging. Fortunately, the Erlang VM provides powerful introspection tools, accessible via the :sys module, which are invaluable for observing a live system.[5]

* **:sys.get_state(pid)**: This allows a developer to retrieve the complete, current state of any running GenServer process. This is the primary tool for inspecting the internal state of a specific user's session to diagnose issues.
* **:sys.get_status(pid)**: Provides more comprehensive information, including the process's state, its supervisor, and other runtime details.
* **:sys.trace(pid, true)**: This function is extremely powerful for debugging state machine logic. It prints all messages sent to and from the specified process's mailbox to the console, allowing a developer to observe the exact sequence of events that led to a particular state.

These tools are essential for maintaining and debugging a complex, stateful OTP application in a production environment.

## VIII. Conclusions

The proposed architecture leverages the strengths of the Elixir/OTP ecosystem to create a robust, scalable, and fault-tolerant system for managing stateful LLM interactions. The design is centered on a SessionServer GenServer, which acts as a state machine for each user's pedagogical journey.

The key architectural principles and recommendations are:

1. **Embrace Process Isolation**: Each user session is managed in its own isolated GenServer process, ensuring that the failure of one session cannot impact others. This aligns with the core "let it crash" philosophy of OTP.
2. **Separate Concerns**: The system is deliberately decomposed into four distinct components: a SessionServer for state logic, a DynamicSupervisor for lifecycle management, a Registry for service discovery, and a ToolExecutor for external interactions. This separation enhances modularity, testability, and maintainability.
3. **Utilize Asynchronous, Non-Blocking Patterns**: For all long-running operations, such as LLM API calls, the Task + monitor pattern is to be used. This ensures the SessionServer remains responsive at all times and can handle failures in external services gracefully.
4. **Formalize State Transitions**: The complex pedagogical logic should be designed and documented as a formal Finite State Machine, preferably using a state transition matrix. This includes the use of transient "locking" states (e.g., :awaiting_tool_result) to prevent race conditions during asynchronous operations.
5. **Plan for Distribution**: While the initial implementation uses a single-node Registry, the design acknowledges the future need for horizontal scalability. The path to a distributed architecture using tools like Horde or alternative routing strategies should be considered a part of the system's evolution.

By adhering to these principles, this design provides a solid foundation for building a sophisticated, interactive learning platform that is not only powerful in its functionality but also resilient and maintainable in its construction.

### Works cited

1. Mastering GenServer for Enhanced Elixir Applications - Curiosum, accessed on September 7, 2025, [https://curiosum.com/blog/what-is-elixir-genserver](https://curiosum.com/blog/what-is-elixir-genserver)
2. Elixir/OTP : Basics of GenServer - Medium, accessed on September 7, 2025, [https://medium.com/elemental-elixir/elixir-otp-basics-of-genserver-18ec78cc3148](https://medium.com/elemental-elixir/elixir-otp-basics-of-genserver-18ec78cc3148)
3. OTP Concurrency - Elixir School, accessed on September 7, 2025, [https://elixirschool.com/en/lessons/advanced/otp_concurrency](https://elixirschool.com/en/lessons/advanced/otp_concurrency)
4. Client-server communication with GenServer — Elixir v1.18.4 - HexDocs, accessed on September 7, 2025, [https://hexdocs.pm/elixir/genservers.html](https://hexdocs.pm/elixir/genservers.html)
5. GenServer — Elixir v1.12.3 - HexDocs, accessed on September 7, 2025, [https://hexdocs.pm/elixir/1.12/GenServer.html](https://hexdocs.pm/elixir/1.12/GenServer.html)
6. Elixir GenServers: Overview and Tutorial - Scout APM, accessed on September 7, 2025, [https://www.scoutapm.com/blog/elixirs-genservers-overview-and-tutorial](https://www.scoutapm.com/blog/elixirs-genservers-overview-and-tutorial)
7. Overview — Erlang System Documentation v28.0.2 - Erlang/OTP, accessed on September 7, 2025, [https://www.erlang.org/doc/system/design_principles.html](https://www.erlang.org/doc/system/design_principles.html)
8. OTP Supervisors - Elixir School, accessed on September 7, 2025, [https://elixirschool.com/en/lessons/advanced/otp_supervisors](https://elixirschool.com/en/lessons/advanced/otp_supervisors)
9. Exploring Elixir's OTP Supervision Trees - CloudDevs, accessed on September 7, 2025, [https://clouddevs.com/elixir/otp-supervision-trees/](https://clouddevs.com/elixir/otp-supervision-trees/)
10. Erlang - Elixir: What is a supervision tree? - Stack Overflow, accessed on September 7, 2025, [https://stackoverflow.com/questions/46554449/erlang-elixir-what-is-a-supervision-tree](https://stackoverflow.com/questions/46554449/erlang-elixir-what-is-a-supervision-tree)
11. Supervision trees and applications — Elixir v1.18.4 - HexDocs, accessed on September 7, 2025, [https://hexdocs.pm/elixir/supervisor-and-application.html](https://hexdocs.pm/elixir/supervisor-and-application.html)
12. GenServer - Elixir, accessed on September 7, 2025, [http://elixir-br.github.io/getting-started/mix-otp/genserver.html](http://elixir-br.github.io/getting-started/mix-otp/genserver.html)
13. Learning Elixir's GenServer with a real-world example - DEV Community, accessed on September 7, 2025, [https://dev.to/_areichert/learning-elixir-s-genserver-with-a-real-world-example-5fef](https://dev.to/_areichert/learning-elixir-s-genserver-with-a-real-world-example-5fef)
14. Managing Distributed State with GenServers in Phoenix and Elixir | AppSignal Blog, accessed on September 7, 2025, [https://blog.appsignal.com/2024/10/29/managing-distributed-state-with-genservers-in-phoenix-and-elixir.html](https://blog.appsignal.com/2024/10/29/managing-distributed-state-with-genservers-in-phoenix-and-elixir.html)
