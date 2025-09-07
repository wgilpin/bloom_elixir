# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Project Bloom is an AI-powered GCSE Mathematics tutoring platform that provides adaptive, one-on-one instruction using Phoenix/Elixir and React. The system uses a pedagogical state machine to diagnose errors and provide targeted remediation.

## Development Commands

### Setup and Dependencies
```bash
cd tutor
mix deps.get             # Install dependencies
mix ecto.create         # Create database
mix ecto.migrate        # Run migrations
npm install --prefix assets  # Install JS dependencies
```

### Development Server
```bash
cd tutor
mix phx.server          # Start Phoenix server on http://localhost:4000
iex -S mix phx.server   # Start with interactive shell
```

### Database Operations
```bash
mix ecto.gen.migration <name>  # Generate new migration
mix ecto.migrate               # Run pending migrations
mix ecto.rollback             # Rollback last migration
mix ecto.reset                # Drop, create, migrate, seed
```

### Testing
```bash
mix test                      # Run all tests
mix test path/to/test.exs    # Run specific test file
mix test --only focus:true   # Run focused tests
```

### Code Quality
```bash
mix format                    # Format Elixir code
mix compile --warnings-as-errors  # Check for compilation warnings
```

## Architecture Overview

### Core Domain Structure

The application follows a domain-driven design with these key contexts:

- **Accounts** (`lib/tutor/accounts/`): User management for students and parents
- **Curriculum** (`lib/tutor/curriculum/`): GCSE syllabus structure and topics
- **Learning** (`lib/tutor/learning/`): Core tutoring logic, sessions, questions, and progress tracking
- **Gamification** (`lib/tutor/gamification/`): Achievement system and engagement mechanics

### OTP Architecture (Planned)

The system will use a supervision tree with:
- **SessionSupervisor**: DynamicSupervisor managing individual tutoring sessions
- **SessionServer**: GenServer maintaining pedagogical state machine per session
- **SessionRegistry**: Registry for session process discovery
- **ToolTaskSupervisor**: Task.Supervisor for async LLM API calls

### Pedagogical State Machine

Sessions transition through states:
- `:exposition` - Presenting concepts or questions
- `:awaiting_answer` - Student working on response
- `:awaiting_tool_result` - Processing LLM API calls
- `:remediating` - Providing targeted intervention

### Database Schema

Key tables and relationships:
- `users` → has_many `session_histories`, `user_progress`, `achievements`
- `syllabuses` → hierarchical topic structure with Foundation/Higher tiers
- `questions` → belongs_to `syllabus`
- `user_progress` → tracks mastery per user/topic combination
- `session_histories` → full conversation and metrics storage

### Real-time Communication

Phoenix Channels will handle WebSocket connections:
- `UserSocket` for authentication
- `SessionChannel` for bidirectional tutoring communication
- Messages routed to appropriate `SessionServer` process

### External Integrations

LLM tools (async via Task):
- `check_answer/2` - Validate student responses
- `generate_question/1` - Create adaptive questions
- `diagnose_error/2` - Identify misconception types
- `create_remediation/2` - Generate targeted interventions
- `explain_concept/2` - Provide concept explanations

## Implementation Status

Phase 1 (Foundation) is complete:
- Phoenix project initialized with LiveView
- Dependencies added (Tesla, Req, Oban, Pow)
- Database schemas created for all core entities
- Migration files generated

Next phases from `docs/plan.md`:
- Phase 2: OTP Architecture
- Phase 3: Real-time Communication
- Phase 4: External Integrations
- Phase 5: Frontend Development

## Key Files

- `docs/PRD.md` - Full product requirements and user stories
- `docs/plan.md` - Detailed 10-week implementation plan
- `mix.exs` - Project dependencies and configuration
- `priv/repo/migrations/` - Database schema definitions
- at the start of each conversation read @docs\PRD.md and @docs\plan.md. Use other docs in /docs as needed
- check off work complete in plan.md for tracking