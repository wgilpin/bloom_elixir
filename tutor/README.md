# Tutor

Project Bloom - AI-powered GCSE Mathematics tutoring platform.

## Prerequisites

- Elixir 1.14+ and Erlang/OTP 25+
- Node.js 18+ (for frontend assets)
- Docker (for PostgreSQL database)

## Quick Start

### Option 1: Use the startup script

```bash
./start.sh
```

### Option 2: Manual setup

1. **Start PostgreSQL database:**

   ```bash
   docker run --name postgres-tutor -e POSTGRES_PASSWORD=postgres -d -p 5432:5432 postgres
   ```

2. **Setup the application:**

   ```bash
   cd tutor
   mix setup  # Install deps, create/migrate DB, setup assets
   ```

3. **Start the Phoenix server:**

   ```bash
   mix phx.server
   ```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Development Commands

- `mix test` - Run tests
- `mix format` - Format code  
- `mix ecto.reset` - Reset database
- `docker stop postgres-tutor && docker rm postgres-tutor` - Remove database container

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

- Official website: <https://www.phoenixframework.org/>
- Guides: <https://hexdocs.pm/phoenix/overview.html>
- Docs: <https://hexdocs.pm/phoenix>
- Forum: <https://elixirforum.com/c/phoenix-forum>
- Source: <https://github.com/phoenixframework/phoenix>
