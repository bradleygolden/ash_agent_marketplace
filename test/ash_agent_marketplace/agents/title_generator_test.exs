defmodule AshAgentMarketplace.Agents.TitleGeneratorTest do
  use ExUnit.Case, async: true

  alias Spark.Dsl.Extension

  defmodule TestDomain do
    use Ash.Domain,
      extensions: [AshAgent.Domain],
      validate_config_inclusion?: false

    agents do
      agent(AshAgentMarketplace.Agents.TitleGenerator,
        client: "openai:gpt-4o",
        provider: :mock
      )
    end
  end

  describe "generated agent configuration" do
    test "has string output schema" do
      output_schema = Extension.get_opt(TestDomain.TitleGenerator, [:agent], :output_schema)
      assert output_schema != nil
    end

    test "has input schema defined" do
      input_schema = Extension.get_opt(TestDomain.TitleGenerator, [:agent], :input_schema)
      assert input_schema != nil
    end

    test "has instruction template defined" do
      instruction = Extension.get_opt(TestDomain.TitleGenerator, [:agent], :instruction)
      assert %Solid.Template{} = instruction
    end

    test "has client from domain registration" do
      client = Extension.get_opt(TestDomain.TitleGenerator, [:agent], :client)
      assert client == {"openai:gpt-4o", []}
    end

    test "has provider from domain registration" do
      provider = Extension.get_opt(TestDomain.TitleGenerator, [:agent], :provider)
      assert provider == :mock
    end
  end

  describe "domain registration" do
    test "generates agent module in domain namespace" do
      assert Code.ensure_loaded?(TestDomain.TitleGenerator)
    end

    test "domain has auto-generated interfaces" do
      assert function_exported?(TestDomain, :call_title_generator, 2)
      assert function_exported?(TestDomain, :call_title_generator!, 2)
      assert function_exported?(TestDomain, :stream_title_generator, 2)
      assert function_exported?(TestDomain, :stream_title_generator!, 2)
    end

    test "generated agent has call and stream actions" do
      actions = Ash.Resource.Info.actions(TestDomain.TitleGenerator)
      action_names = Enum.map(actions, & &1.name)

      assert :call in action_names
      assert :stream in action_names
    end
  end
end
