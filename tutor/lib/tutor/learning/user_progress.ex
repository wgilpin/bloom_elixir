defmodule Tutor.Learning.UserProgress do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_progress" do
    field :mastery_level, :float, default: 0.0
    field :questions_attempted, :integer, default: 0
    field :questions_correct, :integer, default: 0
    field :last_attempt_at, :utc_datetime
    field :error_patterns, {:array, :map}, default: []
    field :strengths, {:array, :string}, default: []
    field :weaknesses, {:array, :string}, default: []

    belongs_to :user, Tutor.Accounts.User
    belongs_to :syllabus, Tutor.Curriculum.Syllabus

    timestamps()
  end

  @doc false
  def changeset(user_progress, attrs) do
    user_progress
    |> cast(attrs, [:mastery_level, :questions_attempted, :questions_correct, 
                     :last_attempt_at, :error_patterns, :strengths, :weaknesses, 
                     :user_id, :syllabus_id])
    |> validate_required([:user_id, :syllabus_id])
    |> validate_number(:mastery_level, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    |> unique_constraint([:user_id, :syllabus_id])
  end
end