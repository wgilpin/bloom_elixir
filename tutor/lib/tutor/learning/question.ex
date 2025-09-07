defmodule Tutor.Learning.Question do
  use Ecto.Schema
  import Ecto.Changeset

  schema "questions" do
    field :content, :string
    field :difficulty, :string, default: "medium"
    field :answer, :string
    field :explanation, :string
    field :hints, {:array, :string}, default: []
    field :metadata, :map

    belongs_to :syllabus, Tutor.Curriculum.Syllabus

    timestamps()
  end

  @doc false
  def changeset(question, attrs) do
    question
    |> cast(attrs, [:content, :difficulty, :answer, :explanation, :hints, :metadata, :syllabus_id])
    |> validate_required([:content, :answer, :syllabus_id])
    |> validate_inclusion(:difficulty, ["easy", "medium", "hard"])
  end
end