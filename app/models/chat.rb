# A conversation with the AI under one Ai::Purpose (docs/design/ai.md, Conversations). It's the person's own;
# household is set when the feature runs inside one. Deleted by Ai::PurgeExpiredChatsJob once older than its
# purpose's keep_for, or kept until the person deletes it when that's nil.
class Chat < ApplicationRecord
  class UnsupportedProvider < StandardError; end

  # The web search options are Anthropic's, and only its citations carry the cited_text the copy check needs
  # (docs/design/ai.md, The model and the web search).
  PROVIDER = "anthropic".freeze

  acts_as_chat

  belongs_to :user
  belongs_to :household, optional: true

  validates :purpose, inclusion: { in: Ai::Purpose.names }

  scope :expired, -> { Ai::Purpose.all.select(&:keep_for).map { where(purpose: it.name, created_at: ...it.keep_for.ago) }.reduce(:or) || none }

  # RubyLLM keeps a chat's usage records (token counts) when the chat goes; Aglowy deletes them with it
  # (docs/design/ai.md, Privacy and cost). Prepended, so it runs before RubyLLM's dependent: :nullify.
  before_destroy -> { ruby_llm_usages.delete_all(:delete_all) }, prepend: true

  # The only way a feature calls the AI: the purpose's instructions, schema and web search, and the person's text
  # inside the marked block. Chunks go to +stream+ as they arrive.
  def ask_within_purpose(text, stream: nil)
    follow_configured_model
    keep_to_request_timeout
    raise UnsupportedProvider, "AI_MODEL must be an #{PROVIDER} model, not #{provider}" unless provider.to_s == PROVIDER

    with_instructions(ai_purpose.instructions)
      .with_schema(ai_purpose.schema)
      .with_provider_tools(web_search: ai_purpose.web_search)
      .with_max_output_tokens(ai_purpose.max_output_tokens)
    keep_recent_context

    Ai::Reply.new(ask(ai_purpose.user_message(text), &stream))
  end

  private
    def ai_purpose
      @ai_purpose ||= Ai::Purpose.find(purpose)
    end

    # A chat keeps the model it was made with, and a personal study's lasts until the person deletes it, so each
    # request moves it to the one AI_MODEL names now (docs/design/ai.md, The model and the web search).
    def follow_configured_model
      with_model(RubyLLM.config.default_model) unless model_id == RubyLLM.config.default_model
    end

    # A purpose with its own timeout gets one try at it: RubyLLM's retries would each wait as long again.
    def keep_to_request_timeout
      return unless (timeout = ai_purpose.request_timeout)

      with_context(RubyLLM.context { it.request_timeout = timeout.to_i; it.max_retries = 0 })
    end

    # Only the purpose's last context_exchanges questions and their replies go with a new question, and the
    # instructions. The messages stay saved; this trims only what's sent. It holds while one run at a time uses the
    # chat (PersonalStudy::AnswerQuestionJob), since RubyLLM reloads the whole history when another run has written.
    def keep_recent_context
      return unless ai_purpose.context_exchanges

      instructions, history = to_llm.messages.partition { it.role == :system }
      to_llm.messages = instructions + history.slice_before { it.role == :user }.to_a.last(ai_purpose.context_exchanges).flatten
    end
end
