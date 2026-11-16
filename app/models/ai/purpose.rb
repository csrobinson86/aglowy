# What one AI feature may do, in one place (docs/design/ai.md, Ai::Purpose): its fixed instructions, the reply
# schema, the hosts its web search may look at, and its limits. Chat#ask_within_purpose applies it.
class Ai::Purpose
  class Unknown < StandardError; end

  ALLOWED_HOSTS = %w[ www.jw.org jw.org wol.jw.org ].freeze
  # The marked block the person's text goes in (safety measure 3). The instructions name it.
  USER_BLOCK = "family_request".freeze

  # Keep in step with the chats_purpose_check constraint.
  def self.names = %w[ family_study_draft ]

  def self.find(name)
    raise Unknown, "No AI purpose called #{name.inspect}" unless name.in?(names)

    "Ai::Purpose::#{name.camelize}".constantize.new
  end

  def name = self.class.name.demodulize.underscore

  def instructions
    @instructions ||= Rails.root.join("config/ai/#{name}.md").read
  end

  def allowed_hosts = ALLOWED_HOSTS

  # The provider's own search tool settings, in Anthropic's terms (docs/design/ai.md, The model and the web search).
  def web_search
    { allowed_domains: allowed_hosts, max_uses: max_searches }
  end

  # The person's text as data inside the marked block. Tags that would close or reopen the block are removed.
  def user_message(text)
    "<#{USER_BLOCK}>\n#{text.to_s.gsub(%r{</?#{USER_BLOCK}>}i, "")}\n</#{USER_BLOCK}>"
  end
end
