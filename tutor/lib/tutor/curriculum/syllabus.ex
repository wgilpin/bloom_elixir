defmodule Tutor.Curriculum.Syllabus do
  use Ecto.Schema
  import Ecto.Changeset

  schema "syllabuses" do
    field :topic, :string
    field :description, :string
    field :tier, :string, default: "foundation"
    field :parent_topic_id, :id
    field :order_index, :integer
    field :content, :map

    has_many :questions, Tutor.Learning.Question
    has_many :user_progress, Tutor.Learning.UserProgress

    timestamps()
  end

  @doc false
  def changeset(syllabus, attrs) do
    syllabus
    |> cast(attrs, [:topic, :description, :tier, :parent_topic_id, :order_index, :content])
    |> validate_required([:topic, :tier])
    |> validate_inclusion(:tier, ["foundation", "higher", "both"])
  end
end