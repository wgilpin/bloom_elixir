defmodule Tutor.Gamification.Achievement do
  use Ecto.Schema
  import Ecto.Changeset

  schema "achievements" do
    field :name, :string
    field :description, :string
    field :badge_url, :string
    field :points, :integer, default: 0
    field :unlocked_at, :utc_datetime
    field :type, :string

    belongs_to :user, Tutor.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(achievement, attrs) do
    achievement
    |> cast(attrs, [:name, :description, :badge_url, :points, :unlocked_at, :type, :user_id])
    |> validate_required([:name, :type, :user_id])
    |> validate_inclusion(:type, ["streak", "mastery", "milestone", "special"])
  end
end