defmodule AshAgentMarketplace.Agents.TitleGenerator do
  @moduledoc """
  Generates concise, compelling titles for text content.

  ## Inputs

  - `text` (required) - The text content to generate a title for
  - `examples` (optional) - Example titles to guide the style and format

  ## Output

  Returns a string containing the generated title.

  ## Example

      MyApp.Agents.call_title_generator!(
        text: "This article explores the latest advances in machine learning...",
        examples: ["The Future of AI", "Why Deep Learning Matters"]
      )
      # => "Machine Learning Breakthroughs Transform Industry"
  """

  use AshAgent.Template

  agent do
    output_schema(Zoi.string())

    input_schema(
      Zoi.object(%{
        text: Zoi.string(),
        examples: Zoi.list(Zoi.string()) |> Zoi.optional()
      })
    )

    prompt ~p"""
    <task>Generate a concise, compelling title for the following text.</task>
    {% for example in examples %}{% if forloop.first %}

    <examples>
    {% endif %}- {{ example }}
    {% if forloop.last %}</examples>
    {% endif %}{% endfor %}
    <text>
    {{ text }}
    </text>

    Respond with only the title, nothing else.
    """
  end
end
