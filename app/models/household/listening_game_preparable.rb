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

  # The saved game, or nil when the week has one already, another run holds its claim, the household has had its
  # requests for today, or the reply had no usable round. :not_allowed, before any claim, chat or request, when no head
  # or adult here has accepted the AI terms. The claim is taken under the household's lock, which is released before the
  # request goes out (When it runs).
  def prepare_listening_game(week_of)
    claimed = with_lock { claim_listening_game(week_of) }
    claimed.is_a?(Array) ? ask_for_listening_game(*claimed) : claimed
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

    # Under the household's lock: no game yet, an owner who has accepted the AI terms, fewer than the purpose's daily
    # limit of requests today where the household lives, and no other run's claim. Then this run's claim, and the chat,
    # made here so the next run's count sees it. The chat is the owner's, in this household.
    def claim_listening_game(week_of)
      return if listening_games.exists?(week_of:)
      owner = listening_game_owner or return :not_allowed
      purpose = Ai::Purpose.find("listening_game")
      return if chats.where(purpose: purpose.name, created_at: today.in_time_zone(time_zone)..).count >= purpose.daily_limit

      claim = listening_game_preparations.find_or_initialize_by(week_of:).take or return
      [ claim, chats.create!(user: owner, purpose: purpose.name) ]
    end

    # Saved, and the claim let go, under the lock and only while the claim is still this run's: a run whose claim was
    # taken over saves nothing and leaves the newer claim. A failed request or a reply with nothing usable lets it go
    # too, so the next daily run tries again.
    def ask_for_listening_game(claim, chat)
      game = listening_game_from_ai(chat, week_of: claim.week_of)
      with_lock { game&.save! if claim.release }
      game if game&.persisted?
    rescue StandardError
      with_lock { claim.release }
      raise
    end

    def listening_game_from_ai(chat, week_of:)
      purpose = Ai::Purpose.find(chat.purpose)
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
