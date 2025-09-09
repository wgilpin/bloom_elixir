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

## VSCode Debugging

This project includes VSCode launch configurations for debugging:

### Prerequisites

Install the recommended VSCode extensions:
- ElixirLS (jakebecker.elixir-ls)
- Phoenix Framework (phoenixframework.phoenix)

VSCode will prompt you to install these when you open the project.

### Running the App with VSCode Debugger

1. **Open the project in VSCode:**
   ```bash
   code .
   ```

2. **Start debugging:**
   - Press `F5` or go to Run → Start Debugging
   - Select "Launch Phoenix Server" from the dropdown
   - The app will start with debugging enabled at http://localhost:4000

### Available Debug Configurations

- **Launch Phoenix Server** - Standard Phoenix server with debugging
- **Launch Phoenix Server with IEx** - Phoenix server with interactive Elixir shell
- **Run Tests** - Run all tests with debugging
- **Run Specific Test** - Debug a specific test file (select file first)

### Setting Breakpoints

1. Open any Elixir file (`.ex` or `.exs`)
2. Click in the gutter next to line numbers to set breakpoints
3. Start debugging with `F5`
4. Trigger the code path in your browser or tests
5. VSCode will pause execution at breakpoints

### Interactive Debugging

When paused at a breakpoint, you can:
- Inspect variables in the Variables panel
- Evaluate expressions in the Debug Console
- Step through code with F10 (step over) and F11 (step into)
- Continue execution with F5

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

- Official website: <https://www.phoenixframework.org/>
- Guides: <https://hexdocs.pm/phoenix/overview.html>
- Docs: <https://hexdocs.pm/phoenix>
- Forum: <https://elixirforum.com/c/phoenix-forum>
- Source: <https://github.com/phoenixframework/phoenix>
