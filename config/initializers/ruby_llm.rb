# AI providers and the model, all from the environment (docs/design/ai.md, The model and the web search).
# Code never names a model: AI_MODEL does. It must name a model whose web search citations carry cited_text
# excerpts, which today means an Anthropic model.
RubyLLM.configure do |config|
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
  # Moderation (Ai::Moderation) uses OpenAI's moderation model.
  config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.default_model = ENV["AI_MODEL"] if ENV["AI_MODEL"].present?
  config.context_budget = { per_result: 0.25, per_request: 0.7 }
end
