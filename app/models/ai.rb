# The AI feature's records and POROs (docs/design/ai.md). Its tables start with ai_.
module Ai
  # The provider's errors, the connection's once RubyLLM's retries run out, and a reply that isn't a JSON object.
  PROVIDER_ERRORS = [ RubyLLM::Error, Faraday::Error, Ai::Reply::Malformed ].freeze

  def self.table_name_prefix = "ai_"
end
