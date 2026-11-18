# Asking the AI for a week's listening game cards (docs/design/listening-game.md, The weekly research job). Nothing here
# fetches jw.org or wol.jw.org: the program's address goes into the question as text (Trap 1), and only the title and
# link of each page the AI used are kept.
module Household::ListeningGamePreparable
  extend ActiveSupport::Concern

  included do
    # Their rounds, cards and sources go with them (on_delete: :cascade).
    has_many :listening_games, dependent: :delete_all
    has_many :listening_game_preparations, class_name: "ListeningGame::Preparation", dependent: :delete_all
  end

  # The saved game, or nil when the week has one already, another run holds its claim, or the reply had no usable round.
  # :not_allowed, before any claim, chat or request, when no head or adult here has accepted the AI terms. The owner
  # is picked and the claim taken under the household's lock, which is released before the request goes out
  # (When it runs). The chat is the owner's, in this household.
  def prepare_listening_game(week_of)
    owner = nil
    claim = with_lock do
      next if listening_games.exists?(week_of:)
      next :not_allowed unless (owner = listening_game_owner)

      listening_game_preparations.find_or_initialize_by(week_of:).take
    end
    claim.is_a?(ListeningGame::Preparation) ? ask_for_listening_game(claim, owner:) : claim
  end

  # This week's game, unless the helper is off, the week has one, or its midweek meeting has passed.
  def prepare_this_weeks_listening_game(now = Time.current)
    prepare_listening_game(listening_game_week(now)) if listening_game_due?(now)
  end

  def prepare_listening_game_later
    ListeningGame::PrepareJob.perform_later(self)
  end

  def listening_game_due?(now = Time.current)
    week_of = listening_game_week(now)
    meeting_helper? && week_of.present? && !listening_games.exists?(week_of:)
  end

  private
    # The Monday of this week's midweek meeting where the household lives (Trap 7), or nil once it has ended or before
    # meeting times are set.
    def listening_game_week(now)
      return unless meeting_times_set?

      meeting = meeting_in(now.in_time_zone(time_zone).to_date.beginning_of_week(:monday), "midweek")
      meeting.week_of if meeting.ends_at > now
    end

    # Saved, and the claim let go, under the lock and only while the claim is still this run's: a run whose claim was
    # taken over saves nothing and leaves the newer claim. A failed request or a reply with nothing usable lets it go
    # too, so the next daily run tries again.
    def ask_for_listening_game(claim, owner:)
      game = listening_game_from_ai(claim.week_of, owner:)
      with_lock { game&.save! if claim.release }
      game if game&.persisted?
    rescue StandardError
      with_lock { claim.release }
      raise
    end

    def listening_game_from_ai(week_of, owner:)
      purpose = Ai::Purpose.find("listening_game")
      chat = chats.create!(user: owner, purpose: purpose.name)
      reply = chat.ask_within_purpose(purpose.sent_text(week_of))
      return if reply.off_topic?

      copy_check = Ai::CopyCheck.new(citations: reply.sources, overlap_words: purpose.copy_overlap_words, quote_max_words: purpose.quote_max_words)
      sources = Ai::SourceLink.keep(reply.sources, search_results: reply.search_results, allowed_hosts: purpose.allowed_hosts)
      ListeningGame.build_from_reply(reply.parsed, sources:, copy_check:, household: self, week_of:, chat:)
    end

    # The first active head or adult who has accepted the AI terms: the person who turned the helper on, then the heads,
    # then the adults, oldest membership first. Never a child, or someone who has left.
    def listening_game_owner
      owners = memberships.active.where(role: %w[ head adult ]).by_role.includes(:user).map(&:user).select(&:accepted_ai_terms?)
      owners.find { it.id == meeting_helper&.enabled_by_id } || owners.first
    end
end
