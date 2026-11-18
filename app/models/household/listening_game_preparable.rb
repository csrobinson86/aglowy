# Asking the AI for a week's listening game cards (docs/design/listening-game.md, The weekly research job, What it asks).
# Nothing here fetches jw.org or wol.jw.org: the program's address goes into the question as text (Trap 1), and only the
# title and link of each page the AI used are kept.
module Household::ListeningGamePreparable
  extend ActiveSupport::Concern

  included do
    # Their rounds, cards and sources go with them (on_delete: :cascade).
    has_many :listening_games, dependent: :delete_all
  end

  # The saved game, nil when no step has a round, or :not_allowed, before any chat or request, when no head or adult
  # here has accepted the AI terms. The chat is the owner's, in this household.
  def prepare_listening_game(week_of)
    owner = listening_game_owner or return :not_allowed

    purpose = Ai::Purpose.find("listening_game")
    chat = chats.create!(user: owner, purpose: purpose.name)
    reply = chat.ask_within_purpose(purpose.sent_text(week_of))
    return if reply.off_topic?

    copy_check = Ai::CopyCheck.new(citations: reply.sources, overlap_words: purpose.copy_overlap_words, quote_max_words: purpose.quote_max_words)
    sources = Ai::SourceLink.keep(reply.sources, search_results: reply.search_results, allowed_hosts: purpose.allowed_hosts)
    ListeningGame.build_from_reply(reply.parsed, sources:, copy_check:, household: self, week_of:, chat:)&.tap(&:save!)
  end

  private
    # The first active head or adult who has accepted the AI terms: the person who turned the helper on, then the heads,
    # then the adults, oldest membership first. Never a child, or someone who has left.
    def listening_game_owner
      owners = memberships.active.where(role: %w[ head adult ]).by_role.includes(:user).map(&:user).select(&:accepted_ai_terms?)
      owners.find { it.id == meeting_helper&.enabled_by_id } || owners.first
    end
end
