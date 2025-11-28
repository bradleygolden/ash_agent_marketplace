defmodule AshAgentMarketplace.Tools.ExaSearch do
  unless Code.ensure_loaded?(Req) do
    raise CompileError,
      description: """
      ExaSearch requires the :req dependency.

      Add to your mix.exs:

          {:req, "~> 0.5"}
      """
  end

  @moduledoc """
  Exa neural search tool for AI agents.

  Exa provides AI-powered semantic search that understands meaning and context,
  not just keywords. It's designed specifically for AI applications.

  ## Configuration

  API key resolution (in priority order):
  1. Explicit config: `tool ExaSearch, config: [api_key: "key"]`
  2. Environment variable: `EXA_API_KEY`
  3. Application config: `config :ash_agent_marketplace, :exa_api_key`

  ## Usage

      defmodule MyApp.ResearchAgent do
        use Ash.Resource,
          domain: MyApp.Agents,
          extensions: [AshAgent.Resource, AshAgentTools.Resource],
          fragments: [AshAgentMarketplace.Tools.ExaSearch]

        agent do
          client "openai:gpt-4o"
          prompt ~p"You are a research assistant. Use exa_search to find information."
        end

        # Optional: explicit declaration
        agent_tools do
          tool AshAgentMarketplace.Tools.ExaSearch
        end
      end

  ## Search Types

  - `:auto` (default) - Automatically chooses the best search type
  - `:neural` - Semantic search that understands meaning
  - `:keyword` - Traditional keyword-based search

  ## Categories

  Filter results by content type: `"research paper"`, `"news"`, `"github"`,
  `"tweet"`, `"company"`, `"linkedin"`, `"pdf"`, etc.
  """

  use AshAgentTools.Template

  agent_tools do
    tool :exa_search do
      description("Search the web using Exa's neural search engine for current information")

      input_schema(
        Zoi.object(
          %{
            query: Zoi.string(description: "The search query"),
            type:
              Zoi.enum([:neural, :keyword, :auto], description: "Search type (default: auto)")
              |> Zoi.optional(),
            num_results:
              Zoi.integer(description: "Number of results to return (max 100, default 10)")
              |> Zoi.optional(),
            category:
              Zoi.string(description: "Content category filter (e.g., 'news', 'research paper')")
              |> Zoi.optional(),
            include_domains:
              Zoi.list(Zoi.string(), description: "Only include results from these domains")
              |> Zoi.optional(),
            exclude_domains:
              Zoi.list(Zoi.string(), description: "Exclude results from these domains")
              |> Zoi.optional(),
            start_published_date:
              Zoi.string(description: "Filter results published after this date (ISO 8601)")
              |> Zoi.optional(),
            end_published_date:
              Zoi.string(description: "Filter results published before this date (ISO 8601)")
              |> Zoi.optional(),
            include_text:
              Zoi.list(Zoi.string(), description: "Only include results containing this text")
              |> Zoi.optional(),
            exclude_text:
              Zoi.list(Zoi.string(), description: "Exclude results containing this text")
              |> Zoi.optional()
          },
          coerce: true
        )
      )

      output_schema(
        Zoi.object(%{
          results:
            Zoi.list(
              Zoi.object(%{
                title: Zoi.string() |> Zoi.nullable(),
                url: Zoi.string(),
                published_date: Zoi.string() |> Zoi.nullable(),
                author: Zoi.string() |> Zoi.nullable(),
                text: Zoi.string() |> Zoi.nullable(),
                highlights: Zoi.list(Zoi.string()) |> Zoi.nullable(),
                summary: Zoi.string() |> Zoi.nullable()
              })
            )
        })
      )

      function({__MODULE__, :execute, []})
    end
  end

  @api_url "https://api.exa.ai/search"

  @doc false
  def execute(args, context) do
    with {:ok, api_key} <- get_api_key(context),
         {:ok, response} <- make_request(api_key, args) do
      {:ok, format_response(response)}
    end
  end

  defp get_api_key(context) do
    # Priority: explicit config > env var > app config
    key =
      get_in(context, [:tool_configs, __MODULE__, :api_key]) ||
        System.get_env("EXA_API_KEY") ||
        Application.get_env(:ash_agent_marketplace, :exa_api_key)

    if key do
      {:ok, key}
    else
      {:error,
       "Exa API key not configured. Set EXA_API_KEY environment variable or configure in your agent."}
    end
  end

  defp make_request(api_key, args) do
    body = build_request_body(args)

    case Req.post(@api_url,
           json: body,
           headers: [{"x-api-key", api_key}]
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, "Exa API error (#{status}): #{inspect(body)}"}

      {:error, error} ->
        {:error, "HTTP request failed: #{inspect(error)}"}
    end
  end

  defp build_request_body(args) do
    %{query: args.query}
    |> maybe_put(:type, args[:type])
    |> maybe_put(:numResults, args[:num_results])
    |> maybe_put(:category, args[:category])
    |> maybe_put(:includeDomains, args[:include_domains])
    |> maybe_put(:excludeDomains, args[:exclude_domains])
    |> maybe_put(:startPublishedDate, args[:start_published_date])
    |> maybe_put(:endPublishedDate, args[:end_published_date])
    |> maybe_put(:includeText, args[:include_text])
    |> maybe_put(:excludeText, args[:exclude_text])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp format_response(%{"results" => results}) do
    %{
      results:
        Enum.map(results, fn r ->
          %{
            title: r["title"],
            url: r["url"],
            published_date: r["publishedDate"],
            author: r["author"],
            text: r["text"],
            highlights: r["highlights"],
            summary: r["summary"]
          }
        end)
    }
  end

  defp format_response(response) do
    # Handle unexpected response format
    %{raw_response: response}
  end
end
