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
    test "has string output type" do
      output = Extension.get_opt(TestDomain.TitleGenerator, [:agent], :output)
      assert output == :string
    end

    test "has text and examples input arguments" do
      args = Extension.get_entities(TestDomain.TitleGenerator, [:agent, :input])
      arg_names = Enum.map(args, & &1.name)

      assert :text in arg_names
      assert :examples in arg_names
    end

    test "text argument is required" do
      args = Extension.get_entities(TestDomain.TitleGenerator, [:agent, :input])
      text_arg = Enum.find(args, &(&1.name == :text))

      assert text_arg.allow_nil? == false
    end

    test "examples argument is optional array of strings" do
      args = Extension.get_entities(TestDomain.TitleGenerator, [:agent, :input])
      examples_arg = Enum.find(args, &(&1.name == :examples))

      assert examples_arg.allow_nil? == true
      assert examples_arg.type == {:array, :string}
    end

    test "has prompt template defined" do
      prompt = Extension.get_opt(TestDomain.TitleGenerator, [:agent], :prompt)
      assert %Solid.Template{} = prompt
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
