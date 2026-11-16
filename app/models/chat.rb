# A conversation with the AI under one Ai::Purpose (docs/design/ai.md, Conversations). It's the person's own;
# household is set when the feature runs inside one. Deleted after 7 days by Ai::PurgeExpiredChatsJob.
class Chat < ApplicationRecord
  RETENTION = 7.days

  acts_as_chat

  belongs_to :user
  belongs_to :household, optional: true

  validates :purpose, inclusion: { in: Ai::Purpose.names }

  scope :expired, -> { where(created_at: ...RETENTION.ago) }

  # RubyLLM keeps a chat's usage records (token counts) when the chat goes; Aglowy deletes them with it
  # (docs/design/ai.md, Privacy and cost). Prepended, so it runs before RubyLLM's dependent: :nullify.
  before_destroy -> { ruby_llm_usages.delete_all(:delete_all) }, prepend: true

  # The only way a feature calls the AI: the purpose's instructions, schema and web search, and the person's text
  # inside the marked block. Chunks go to +stream+ as they arrive.
  def ask_within_purpose(text, stream: nil)
    with_instructions(ai_purpose.instructions)
      .with_schema(ai_purpose.schema)
      .with_provider_tools(web_search: ai_purpose.web_search)
      .with_max_output_tokens(ai_purpose.max_output_tokens)

    Ai::Reply.new(ask(ai_purpose.user_message(text), &stream))
  end

  private
    def ai_purpose
      @ai_purpose ||= Ai::Purpose.find(purpose)
    end
end
