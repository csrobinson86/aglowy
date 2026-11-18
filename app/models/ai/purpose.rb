# What one AI feature may do, in one place (docs/design/ai.md, Ai::Purpose): its fixed instructions, the reply
# schema, the hosts its web search may look at, and its limits. Chat#ask_within_purpose applies it.
class Ai::Purpose
  class Unknown < StandardError; end

  ALLOWED_HOSTS = %w[ www.jw.org jw.org wol.jw.org ].freeze
  # Each purpose's name, as chats and ai_uses store it, and its class.
  # Keep in step with the chats_purpose_check and ai_uses_purpose_check constraints.
  CLASSES = { "family_study_draft" => "Ai::Purpose::FamilyStudyDraft", "personal_study" => "Ai::Purpose::PersonalStudyAnswer",
              "meeting_part" => "Ai::Purpose::MeetingPart", "daily_brief" => "Ai::Purpose::DailyBrief",
              "listening_game" => "Ai::Purpose::ListeningGame" }.freeze

  def self.names = CLASSES.keys

  def self.find(name)
    raise Unknown, "No AI purpose called #{name.inspect}" unless name.in?(names)

    CLASSES[name].constantize.new
  end

  def self.all = names.map { find(it) }

  def name = CLASSES.key(self.class.name)

  def instructions
    @instructions ||= Rails.root.join("config/ai/#{name}.md").read
  end

  def allowed_hosts = ALLOWED_HOSTS

  # How long its chats are kept, or nil for until the person deletes them (safety measure 10).
  def keep_for = nil

  # The most earlier questions and replies sent with a new one, or nil for the whole chat.
  def context_exchanges = nil

  # The copy check's policy values (safety measure 5), Casey's to tune: as many words in a row shared with a source
  # as make a sentence a copy, and the most words a quotation may hold.
  def copy_overlap_words = 8
  def quote_max_words = 5

  # The provider's own search tool settings, in Anthropic's terms (docs/design/ai.md, The model and the web search).
  def web_search
    { allowed_domains: allowed_hosts, max_uses: max_searches }
  end

  # The person's text as data inside the marked block. Every < and > goes, so no tag in it can close the block,
  # however it's spelled or nested.
  def user_message(text)
    "<#{user_block}>\n#{text.to_s.delete("<>")}\n</#{user_block}>"
  end
end
