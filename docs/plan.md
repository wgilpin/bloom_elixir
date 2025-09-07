# Step-by-Step Implementation Plan for Project Bloom

## Overview

This document outlines the comprehensive implementation plan for Project Bloom, an AI-powered GCSE Mathematics tutoring platform built with Elixir/Phoenix and React.

## Phase 1: Foundation (Week 1-2)

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

## Phase 2: Core OTP Architecture (Week 2-3)

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

## Phase 3: Real-time Communication (Week 3-4)

- [x] **Task 5: Phoenix Channels Implementation**
  - [x] Implement UserSocket authentication
  - [x] Create SessionChannel for bidirectional communication
  - [x] Implement message routing to SessionServer
  - [x] Implement error handling and reconnection logic

- [ ] **Task 6: Pedagogical State Machine**
  - [ ] Define states: `:exposition`, `:awaiting_answer`, `:awaiting_tool_result`, `:remediating`
  - [ ] Implement state transition matrix
  - [ ] Build initial error diagnosis engine
  - [ ] Build adaptive intervention logic

## Phase 4: External Integrations (Week 4-5)

- [ ] **Task 7: LLM Integration Service**
  - [ ] Implement `TutorEx.Tools.check_answer/2`
  - [ ] Implement `TutorEx.Tools.generate_question/1`
  - [ ] Implement `TutorEx.Tools.diagnose_error/2`
  - [ ] Implement `TutorEx.Tools.create_remediation/2`
  - [ ] Implement `TutorEx.Tools.explain_concept/2`

## Phase 5: Frontend Development (Week 5-7)

- [ ] **Task 8: React Chat Interface**
  - [ ] Set up Phoenix Channels JavaScript client
  - [ ] Implement message rendering with markdown support
  - [ ] Add mathematical notation (KaTeX/MathJax)
  - [ ] Add real-time typing indicators

- [ ] **Task 9: Syllabus Navigation UI**
  - [ ] Implement topic tree visualization
  - [ ] Add Foundation/Higher tier toggle
  - [ ] Implement "Assess My Skills" vs "Browse Sub-skills" flow
  - [ ] Add progress indicators per topic

- [ ] **Task 10: Progress Visualization**
  - [ ] Create Mastery bar component (0-100%)
  - [ ] Create skill tree with completion states
  - [ ] Create historical progress charts
  - [ ] Create error pattern analysis display

## Phase 6: User Features (Week 7-8)

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

## Phase 7: Infrastructure (Week 8-9)

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

## Phase 8: Quality Assurance (Week 9-10)

- [ ] **Task 15: Testing & Documentation**
  - [ ] Write unit tests for GenServers
  - [ ] Write integration tests for Channels
  - [ ] Write E2E tests for critical flows
  - [ ] Create API documentation
  - [ ] Create deployment guides

## Implementation Priority Order

### MVP Core Loop (Weeks 1-4)

- [x] Basic Phoenix setup
- [ ] SessionServer with simple state machine
- [ ] Basic chat interface
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
- [x] **Frontend**: React with Phoenix Channels JS client
- [x] **Database**: PostgreSQL with Ecto for persistence

## Development Milestones

### Milestone 1: Basic Chat (Week 2)

- [ ] User can connect via WebSocket
- [ ] Messages are processed by SessionServer
- [ ] Basic responses are generated

### Milestone 2: Learning Loop (Week 4)

- [ ] Questions can be presented
- [ ] Answers are validated
- [ ] Progress is tracked

### Milestone 3: Adaptive Learning (Week 6)

- [ ] Error diagnosis works
- [ ] Remediation is triggered
- [ ] Mastery is calculated

### Milestone 4: Full Feature Set (Week 8)

- [ ] Parent portal functional
- [ ] Gamification active
- [ ] Full syllabus available

### Milestone 5: Production Ready (Week 10)

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
- [ ] Implement minimal SessionServer
- [ ] Build simple chat interface
- [ ] Begin iterative development following this plan
