import Config

config :ash, :validate_domain_resource_inclusion?, false

config :ash_agent, :req_llm_options, req_http_options: [plug: {Req.Test, AshAgent.LLMStub}]

config :ash_baml,
  clients: [
    test: {AshBaml.Test.BamlClient, baml_src: "../ash_baml/test/support/fixtures/baml_src"}
  ]

config :logger, level: :error
