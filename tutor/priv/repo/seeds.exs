# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Tutor.Repo.insert!(%Tutor.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Tutor.Repo
alias Tutor.Curriculum.Syllabus

# Clear existing data (in development only)
if Mix.env() == :dev do
  Repo.delete_all(Syllabus)
end

# GCSE Mathematics Topics - Foundation and Higher Tier
topics = [
  %{
    topic: "Number",
    description: "Work with integers, decimals, fractions, and percentages. Understand place value and rounding.",
    tier: "both",
    order_index: 1
  },
  %{
    topic: "Algebra",
    description: "Solve equations, work with expressions, and understand algebraic manipulation.",
    tier: "both", 
    order_index: 2
  },
  %{
    topic: "Ratio and Proportion",
    description: "Understand ratios, direct and inverse proportion, and percentage changes.",
    tier: "both",
    order_index: 3
  },
  %{
    topic: "Geometry and Measures",
    description: "Work with shapes, angles, area, perimeter, and volume. Understand transformations.",
    tier: "both",
    order_index: 4
  },
  %{
    topic: "Probability",
    description: "Calculate probabilities, work with probability trees and Venn diagrams.",
    tier: "both",
    order_index: 5
  },
  %{
    topic: "Statistics", 
    description: "Analyze data using averages, spread, and different types of graphs and charts.",
    tier: "both",
    order_index: 6
  },
  %{
    topic: "Quadratic Functions",
    description: "Work with quadratic equations, factoring, and the quadratic formula.",
    tier: "higher",
    order_index: 7
  },
  %{
    topic: "Trigonometry",
    description: "Use sine, cosine, tangent and the sine/cosine rules in triangles.",
    tier: "higher", 
    order_index: 8
  },
  %{
    topic: "Graphs and Functions",
    description: "Understand different types of graphs, transformations, and function notation.",
    tier: "higher",
    order_index: 9
  },
  %{
    topic: "Circle Theorems",
    description: "Apply circle theorems and understand properties of circles.",
    tier: "higher",
    order_index: 10
  }
]

# Insert topics
Enum.each(topics, fn topic_attrs ->
  %Syllabus{}
  |> Syllabus.changeset(topic_attrs)
  |> Repo.insert!()
end)

IO.puts("✅ Seeded #{length(topics)} mathematics topics")