# Step-by-Step Implementation Plan for Project Bloom

## Overview

This document outlines the comprehensive implementation plan for Project Bloom, an AI-powered GCSE Mathematics tutoring platform built with Elixir/Phoenix and React.

## Phase 1: Foundation

- [x] **Task 1: Create Phoenix Project Structure**
  - [x] Initialize Phoenix project with LiveView: `mix phx.new tutor --live`
  - [x] Add dependencies to `mix.exs`:
    - [x] `{:tesla, "~> 1.7"}` for HTTP client
    - [x] `{:req, "~> 0.4"}` for API calls
    - [x] `{:jason, "~> 1.4"}` for JSON handling
    - [x] `{:oban, "~> 2.15"}` for background jobs
    - [x] `{:pow, "~> 1.0"}` for authentication

- [x] **Task 2: Database Setup**
  - [x] Configure PostgreSQL connection
  - [x] Create Ecto schemas:
    - [x] `users` (students/parents)
    - [x] `syllabuses` (GCSE math topics)
    - [x] `session_histories`
    - [x] `questions`
    - [x] `user_progress`
    - [x] `achievements`

## Phase 2: Core OTP Architecture

- [x] **Task 3: Implement Supervision Tree**
  - [x] Define `TutorEx.Application` structure
  - [x] Add `Phoenix.Endpoint`
  - [x] Add `Ecto.Repo`
  - [x] Add `SessionSupervisor` (DynamicSupervisor)
  - [x] Add `SessionRegistry` (Registry)
  - [x] Add `ToolTaskSupervisor` (Task.Supervisor)

- [x] **Task 4: Build SessionServer GenServer**
  - [x] Define state structure with pedagogical FSM
  - [x] Implement client API (start_link, handle_user_message, etc.)
  - [x] Implement async tool execution pattern (Task + monitor)
  - [x] Implement state persistence callbacks

## Phase 3: Real-time Communication

- [x] **Task 5: Phoenix Channels Implementation**
  - [x] Implement UserSocket authentication
  - [x] Create SessionChannel for bidirectional communication
  - [x] Implement message routing to SessionServer
  - [x] Implement error handling and reconnection logic

- [x] **Task 6: Pedagogical State Machine**
  - [x] Define core pedagogical states:
    - [x] `:initializing` - Session setup and context loading
    - [x] `:exposition` - Primary instructional/lecture mode
    - [x] `:setting_question` - Question formulation and presentation
    - [x] `:awaiting_answer` - Passive listening for student response
    - [x] `:evaluating_answer` - Processing submission (maps to `:awaiting_tool_result`)
    - [x] `:providing_feedback_correct` - Positive reinforcement
    - [x] `:remediating_known_error` - Targeted error correction
    - [x] `:remediating_unknown_error` - Socratic guidance
    - [x] `:guiding_student` - Multi-turn dialogue support
    - [x] `:session_complete` - Terminal state with summary
  - [x] Implement state transition matrix:
    - [x] Primary Learning Loop (happy path)
    - [x] Remediation Loop (known errors)
    - [x] Guidance Loop (unknown errors)
  - [x] Build error diagnosis engine:
    - [x] Pattern matching for common misconceptions
    - [x] Async tool integration for error analysis
  - [x] Build adaptive intervention logic:
    - [x] Tailored hints for known errors
    - [x] Socratic questioning for unknown errors
    - [x] Progressive hint system in guidance mode

## Phase 4: External Integrations

- [x] **Task 7: LLM Integration Service**
  - [x] Implement `TutorEx.Tools.check_answer/2`
  - [x] Implement `TutorEx.Tools.generate_question/1`
  - [x] Implement `TutorEx.Tools.diagnose_error/2`
  - [x] Implement `TutorEx.Tools.create_remediation/2`
  - [x] Implement `TutorEx.Tools.explain_concept/2`

## Phase 5: Frontend Development

- [x] **Task 8: Phoenix LiveView Chat Interface**
  - [x] Create main tutoring session LiveView
  - [x] Implement real-time message rendering with markdown support
  - [x] Add mathematical notation support (KaTeX/MathJax)
  - [x] Add real-time typing indicators using LiveView events
  - [x] Implement message history with scroll-to-bottom functionality

- [ ] **Task 9: Syllabus Navigation LiveView**
  - [ ] Create topic tree visualization using LiveView components
  - [ ] Add Foundation/Higher tier toggle with live updates
  - [ ] Implement "Assess My Skills" vs "Browse Sub-skills" flow
  - [ ] Add progress indicators per topic with live updates

- [ ] **Task 10: Progress Visualization LiveViews**
  - [ ] Create Mastery bar LiveView component (0-100%)
  - [ ] Create skill tree with live completion state updates
  - [ ] Create historical progress charts using LiveView and Chart.js
  - [ ] Create error pattern analysis display with live updates

## Phase 6: User Features

- [ ] **Task 11: Parent Portal**
  - [ ] Implement separate authentication flow
  - [ ] Build progress dashboard with key metrics
  - [ ] Add areas of difficulty highlighting
  - [ ] Build session history viewer

- [ ] **Task 12: Gamification System**
  - [ ] Build points calculation engine
  - [ ] Implement streak tracking (Process.send_after for daily checks)
  - [ ] Build achievement unlock system
  - [ ] Build leaderboard with privacy controls

## Phase 7: Infrastructure

- [ ] **Task 13: Authentication & Authorization**
  - [ ] Implement Student/Parent account types
  - [ ] Build account linking mechanism
  - [ ] Implement session management
  - [ ] Implement password reset flow

- [ ] **Task 14: Monitoring & Observability**
  - [ ] Set up Telemetry integration
  - [ ] Define custom metrics (DAU/MAU, session length)
  - [ ] Integrate error tracking (Sentry/AppSignal)
  - [ ] Set up performance monitoring

## Phase 8: Quality Assurance

- [ ] **Task 15: Testing & Documentation**
  - [ ] Write unit tests for GenServers
  - [ ] Write integration tests for Channels
  - [ ] Write E2E tests for critical flows
  - [ ] Create API documentation
  - [ ] Create deployment guides

## Implementation Priority Order

### MVP Core Loop (Weeks 1-4)

- [x] Basic Phoenix setup
- [x] SessionServer with simple state machine
- [x] Basic LiveView chat interface
- [ ] Mock LLM responses for testing

### Real Integration (Weeks 4-6)

- [ ] Actual LLM API integration
- [ ] Question generation
- [ ] Answer validation
- [ ] Basic progress tracking

### Enhanced Features (Weeks 6-8)

- [ ] Full syllabus structure
- [ ] Remediation flows
- [ ] Parent portal
- [ ] Gamification

### Production Ready (Weeks 8-10)

- [ ] Authentication
- [ ] Monitoring
- [ ] Performance optimization
- [ ] Deployment preparation

## Key Technical Decisions

- [x] **State Management**: In-memory GenServer state with periodic persistence
- [x] **Communication**: WebSockets via Phoenix Channels for real-time interaction
- [x] **Scalability**: Single-node initially, with Registry pattern ready for distribution
- [x] **LLM Integration**: Async Task pattern to prevent blocking
- [x] **Frontend**: Phoenix LiveView for real-time UI with server-side rendering
- [x] **Database**: PostgreSQL with Ecto for persistence

## Development Milestones

### Milestone 1: Basic Chat

- [x] User can connect via LiveView
- [x] Messages are processed by SessionServer
- [ ] Basic responses are generated and displayed in real-time

### Milestone 2: Learning Loop

- [ ] Questions can be presented
- [ ] Answers are validated
- [ ] Progress is tracked

### Milestone 3: Adaptive Learning

- [ ] Error diagnosis works
- [ ] Remediation is triggered
- [ ] Mastery is calculated

### Milestone 4: Full Feature Set

- [ ] Parent portal functional
- [ ] Gamification active
- [ ] Full syllabus available

### Milestone 5: Production Ready

- [ ] Authentication complete
- [ ] Monitoring in place
- [ ] Performance optimized
- [ ] Ready for deployment

## Risk Mitigation

### Technical Risks

- [ ] **LLM Latency**: Mitigate with async pattern and caching
- [ ] **Scalability**: Start with single-node, prepare for distribution
- [ ] **State Loss**: Implement periodic persistence and session recovery

### Product Risks

- [ ] **User Engagement**: Early gamification implementation
- [ ] **Content Quality**: Iterative testing with educators
- [ ] **Parent Adoption**: Simple, clear dashboard from start

## Success Criteria

- [ ] System handles 1000+ concurrent sessions
- [ ] Average response time < 2 seconds
- [ ] 99.9% uptime during school hours
- [ ] Session recovery works seamlessly
- [ ] Parent portal adoption > 40%

## Next Steps

- [x] Set up development environment
- [x] Initialize Phoenix project
- [x] Create basic database schema
- [x] Implement minimal SessionServer
- [x] Build simple chat interface
- [ ] Connect LiveView to SessionServer with mock LLM responses
- [ ] Begin iterative development following this plan
