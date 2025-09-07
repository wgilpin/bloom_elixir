defmodule Tutor.Repo do
  use Ecto.Repo,
    otp_app: :tutor,
    adapter: Ecto.Adapters.Postgres
end
