defmodule Tutor.Repo.Migrations.CreateInitialTables do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :name, :string, null: false
      add :role, :string, null: false, default: "student"
      add :parent_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    create unique_index(:users, [:email])

    create table(:syllabuses) do
      add :topic, :string, null: false
      add :description, :string
      add :tier, :string, null: false, default: "foundation"
      add :parent_topic_id, references(:syllabuses, on_delete: :nothing)
      add :order_index, :integer
      add :content, :map

      timestamps()
    end

    create index(:syllabuses, [:parent_topic_id])

    create table(:session_histories) do
      add :session_id, :string, null: false
      add :messages, {:array, :map}, default: []
      add :duration_minutes, :integer
      add :questions_attempted, :integer, default: 0
      add :questions_correct, :integer, default: 0
      add :topics_covered, {:array, :string}, default: []
      add :ended_at, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:session_histories, [:session_id])
    create index(:session_histories, [:user_id])

    create table(:questions) do
      add :content, :string, null: false
      add :difficulty, :string, default: "medium"
      add :answer, :string, null: false
      add :explanation, :string
      add :hints, {:array, :string}, default: []
      add :metadata, :map
      add :syllabus_id, references(:syllabuses, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:questions, [:syllabus_id])

    create table(:user_progress) do
      add :mastery_level, :float, default: 0.0
      add :questions_attempted, :integer, default: 0
      add :questions_correct, :integer, default: 0
      add :last_attempt_at, :utc_datetime
      add :error_patterns, {:array, :map}, default: []
      add :strengths, {:array, :string}, default: []
      add :weaknesses, {:array, :string}, default: []
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :syllabus_id, references(:syllabuses, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:user_progress, [:user_id, :syllabus_id])

    create table(:achievements) do
      add :name, :string, null: false
      add :description, :string
      add :badge_url, :string
      add :points, :integer, default: 0
      add :unlocked_at, :utc_datetime
      add :type, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:achievements, [:user_id])
  end
end
