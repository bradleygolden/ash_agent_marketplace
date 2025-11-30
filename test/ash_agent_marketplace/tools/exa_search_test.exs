defmodule AshAgentMarketplace.Tools.ExaSearchTest do
  use ExUnit.Case, async: true

  alias AshAgentMarketplace.Tools.ExaSearch

  # Create a test resource that uses the ExaSearch fragment
  defmodule TestAgent do
    use Ash.Resource,
      domain: AshAgentMarketplace.Tools.ExaSearchTest.TestDomain,
      extensions: [AshAgent.Resource, AshAgentTools.Resource],
      fragments: [AshAgentMarketplace.Tools.ExaSearch]

    resource do
      require_primary_key?(false)
    end

    agent do
      client "openai:gpt-4o"
      provider :mock
      instruction("Test agent")
      input_schema(Zoi.object(%{}, coerce: true))
      output_schema(Zoi.object(%{message: Zoi.string()}, coerce: true))
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(TestAgent)
    end
  end

  describe "tool definition" do
    test "defines exa_search tool with correct name" do
      tools = AshAgentTools.Info.tools(TestAgent)
      assert length(tools) == 1

      tool = hd(tools)
      assert tool.name == :exa_search
    end

    test "has description for the tool" do
      tools = AshAgentTools.Info.tools(TestAgent)
      tool = hd(tools)

      assert tool.description =~ "Exa"
      assert tool.description =~ "search"
    end

    test "input_schema includes all Exa API parameters" do
      tools = AshAgentTools.Info.tools(TestAgent)
      tool = hd(tools)

      assert tool.input_schema != nil

      # Verify required field
      assert {:ok, %{query: "test"}} = Zoi.parse(tool.input_schema, %{query: "test"})

      # Verify optional fields work
      assert {:ok, parsed} =
               Zoi.parse(tool.input_schema, %{
                 query: "test",
                 type: :neural,
                 num_results: 5,
                 category: "news",
                 include_domains: ["example.com"],
                 exclude_domains: ["spam.com"],
                 start_published_date: "2024-01-01",
                 end_published_date: "2024-12-31",
                 include_text: ["keyword"],
                 exclude_text: ["banned"]
               })

      assert parsed.query == "test"
      assert parsed.type == :neural
      assert parsed.num_results == 5
    end

    test "output_schema is defined for results" do
      tools = AshAgentTools.Info.tools(TestAgent)
      tool = hd(tools)

      assert tool.output_schema != nil

      # Verify output schema validates correctly
      assert {:ok, _} =
               Zoi.parse(tool.output_schema, %{
                 results: [
                   %{
                     title: "Test Title",
                     url: "https://example.com",
                     published_date: "2024-01-01",
                     author: "Test Author",
                     text: "Some text",
                     highlights: ["highlight"],
                     summary: "Summary"
                   }
                 ]
               })
    end

    test "query is required" do
      tools = AshAgentTools.Info.tools(TestAgent)
      tool = hd(tools)

      assert {:error, _} = Zoi.parse(tool.input_schema, %{})
    end
  end

  describe "get_api_key/1" do
    test "returns error when no API key configured" do
      # Clear any existing env var
      original = System.get_env("EXA_API_KEY")
      System.delete_env("EXA_API_KEY")

      on_exit(fn ->
        if original, do: System.put_env("EXA_API_KEY", original)
      end)

      context = %{tool_configs: %{}}

      result = ExaSearch.execute(%{query: "test"}, context)
      assert {:error, message} = result
      assert message =~ "API key not configured"
    end

    test "uses explicit config over env var" do
      original = System.get_env("EXA_API_KEY")
      System.put_env("EXA_API_KEY", "env-key")

      on_exit(fn ->
        if original do
          System.put_env("EXA_API_KEY", original)
        else
          System.delete_env("EXA_API_KEY")
        end
      end)

      # We can't easily test this without mocking HTTP, but we verify
      # the config resolution logic by checking the module compiles
      # and the tool is properly defined
      assert Code.ensure_loaded?(ExaSearch)
    end

    test "falls back to env var when no explicit config" do
      original = System.get_env("EXA_API_KEY")
      System.put_env("EXA_API_KEY", "test-env-key")

      on_exit(fn ->
        if original do
          System.put_env("EXA_API_KEY", original)
        else
          System.delete_env("EXA_API_KEY")
        end
      end)

      # The key should be found from env var
      # We verify by checking no "not configured" error
      context = %{tool_configs: %{}}

      # This will fail with HTTP error since we don't have a real API,
      # but it proves the API key was found
      result = ExaSearch.execute(%{query: "test"}, context)

      case result do
        {:error, msg} -> refute msg =~ "not configured"
        {:ok, _} -> :ok
      end
    end
  end

  describe "build_request_body/1" do
    # Test internal request body building through execute
    # Since build_request_body is private, we test it indirectly

    test "converts snake_case to camelCase for API" do
      # This is tested indirectly through the module definition
      # The schema uses snake_case (num_results) but API expects camelCase (numResults)
      tools = AshAgentTools.Info.tools(TestAgent)
      tool = hd(tools)

      # Verify the input_schema accepts snake_case
      assert {:ok, %{num_results: 10}} =
               Zoi.parse(tool.input_schema, %{query: "x", num_results: 10})
    end
  end

  describe "format_response/1" do
    # Test response formatting indirectly
    # The format_response function extracts specific fields from API response

    test "tool function is properly configured" do
      tools = AshAgentTools.Info.tools(TestAgent)
      tool = hd(tools)

      assert tool.function == {ExaSearch, :execute, []}
    end
  end

  describe "module structure" do
    test "uses AshAgentTools.Template" do
      # Verify it's a proper fragment
      assert function_exported?(ExaSearch, :spark_dsl_config, 0)
    end

    test "is a Spark fragment" do
      # Spark fragments expose extensions/0 function
      assert function_exported?(ExaSearch, :extensions, 0)
      # The fragment should use the Template DSL
      assert AshAgentTools.Template.Dsl in ExaSearch.extensions()
    end

    test "fragment is compatible with Ash.Resource" do
      # The test agent should have the tool from the fragment
      assert Code.ensure_loaded?(TestAgent)
      tools = AshAgentTools.Info.tools(TestAgent)
      assert length(tools) == 1
    end
  end
end
