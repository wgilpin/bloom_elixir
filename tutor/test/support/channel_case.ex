defmodule TutorWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.

  Such tests rely on `Phoenix.ChannelTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use TutorWeb.ChannelCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint TutorWeb.Endpoint

      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import TutorWeb.ChannelCase
    end
  end

  setup tags do
    Tutor.DataCase.setup_sandbox(tags)
    :ok
  end
end