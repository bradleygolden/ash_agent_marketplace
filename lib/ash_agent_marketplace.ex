defmodule AshAgentMarketplace do
  @moduledoc """
  A collection of ready-to-use agent templates for the Ash Agent framework.

  This package provides pre-built, provider-agnostic agent templates that can be
  registered in your domain with any LLM provider.

  ## Available Agents

  - `AshAgentMarketplace.Agents.TitleGenerator` - Generates titles for text content

  ## Quick Start Mode

  Register templates in your domain with your preferred LLM client:

      defmodule MyApp.Agents do
        use Ash.Domain, extensions: [AshAgent.Domain]

        agents do
          agent AshAgentMarketplace.Agents.TitleGenerator,
            client: "openai:gpt-4o"
        end
      end

  This generates `MyApp.Agents.TitleGenerator` as a real agent module with
  auto-generated domain interfaces:

      MyApp.Agents.call_title_generator!(text: "Your content here...")
      MyApp.Agents.stream_title_generator!(text: "Your content here...")

  ### Options

  - `:client` (required) - The LLM client string (e.g., `"openai:gpt-4o"`, `"anthropic:claude-3-5-sonnet"`)
  - `:provider` - The provider implementation (defaults to `:req_llm`)
  - `:as` - Override the generated module name
  - `:extensions` - Additional Ash extensions to include

  ### Adding Extensions

  You can add extensions like `AshAgentStudio.Resource` when registering:

      agents do
        agent AshAgentMarketplace.Agents.TitleGenerator,
          client: "openai:gpt-4o",
          extensions: [AshAgentStudio.Resource]
      end

  ## Full Control Mode

  For advanced customization, use templates as Spark fragments in your own resource:

      defmodule MyApp.Agents.CustomTitleGenerator do
        use Ash.Resource,
          domain: MyApp.Agents,
          extensions: [AshAgent.Resource],
          fragments: [AshAgentMarketplace.Agents.TitleGenerator]

        agent do
          client "openai:gpt-4o"
          hooks MyApp.CustomHooks
        end

        attributes do
          uuid_primary_key :id
          timestamps()
        end
      end

  This gives you full control over the resource definition while inheriting
  the template's output type, input arguments, and prompt.

  ## Creating Your Own Templates

  Templates use `AshAgent.Template` which creates a Spark fragment:

      defmodule MyApp.Templates.Summarizer do
        use AshAgent.Template

        agent do
          output :string

          input do
            argument :text, :string, allow_nil?: false
          end

          prompt ~p"Summarize the following text: {{ text }}"
        end
      end

  Templates can define any aspect of the agent DSL (output, inputs, prompt,
  hooks, token_budget, etc.) except client and provider, making them portable
  across different LLM providers. When used as a fragment, the template's DSL
  is merged with the consumer's resource definition.
  """
end
