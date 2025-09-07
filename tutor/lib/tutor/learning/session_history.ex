defmodule Tutor.Learning.SessionHistory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "session_histories" do
    field :session_id, :string
    field :messages, {:array, :map}, default: []
    field :duration_minutes, :integer
    field :questions_attempted, :integer, default: 0
    field :questions_correct, :integer, default: 0
    field :topics_covered, {:array, :string}, default: []
    field :ended_at, :utc_datetime

    belongs_to :user, Tutor.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(session_history, attrs) do
    session_history
    |> cast(attrs, [:session_id, :messages, :duration_minutes, :questions_attempted, 
                     :questions_correct, :topics_covered, :ended_at, :user_id])
    |> validate_required([:session_id, :user_id])
    |> unique_constraint(:session_id)
  end
end