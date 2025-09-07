defmodule Tutor.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :name, :string
    field :role, :string, default: "student"
    field :parent_id, :id

    has_many :session_histories, Tutor.Learning.SessionHistory
    has_many :user_progress, Tutor.Learning.UserProgress
    has_many :achievements, Tutor.Gamification.Achievement

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :role, :parent_id])
    |> validate_required([:email, :name, :role])
    |> validate_inclusion(:role, ["student", "parent"])
    |> unique_constraint(:email)
  end
end