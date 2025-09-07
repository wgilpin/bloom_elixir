ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Tutor.Repo, :manual)

# Configure Mox for testing
Mox.defmock(Tutor.Tools.Mock, for: Tutor.Tools.MockBehaviour)

# Set the mock as the default implementation for tests
Application.put_env(:tutor, :tools_module, Tutor.Tools.Mock)
