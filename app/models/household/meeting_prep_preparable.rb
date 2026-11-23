# Asking the AI for a week's Get ready cards (docs/design/meeting-prep.md, The weekly AI job), under the same claim,
# owner and AI-terms rules as the listening game. A run asks only for the parts still missing a card and fills them in,
# never replacing a saved card. Nothing here fetches jw.org or wol.jw.org: the program's address goes into the question
# as text (Trap 1), and only the title and link of each page the AI used are kept.
module Household::MeetingPrepPreparable
  extend ActiveSupport::Concern

  included do
    # Their cards and sources go with them (on_delete: :cascade).
    has_many :prep_weeks, dependent: :delete_all
    has_many :prep_week_preparations, class_name: "PrepWeek::Preparation", dependent: :delete_all
  end

  # The week with the cards it saved, or nil when no part is missing a card, another run holds the week's claim, the
  # household has had its requests for today, or the reply had no usable card for a missing part. :not_allowed, before
  # any claim, chat or request, when no head or adult here has accepted the AI terms. The claim is taken under the
  # household's lock, which is released before the request goes out.
  def prepare_meeting_prep(week_of)
    claimed = with_lock { claim_meeting_prep(week_of) }
    claimed.is_a?(Array) ? ask_for_meeting_prep(*claimed) : claimed
  end

  # The cards still missing from this week, the Monday where the household lives (Trap 7), unless Get ready is off.
  # A week with every card it can still use asks for nothing.
  def prepare_this_weeks_meeting_prep
    prepare_meeting_prep(today.beginning_of_week(:monday)) if meeting_prep?
  end

  # Nothing while meeting times aren't set: there's no meeting to get ready for.
  def prepare_meeting_prep_later
    PrepWeek::PrepareJob.perform_later(self) if meeting_times_set?
  end

  # A week's cards and sources, or nil while it has none.
  def prep_week_for(week_of)
    prep_weeks.preloaded.find_by(week_of:)
  end

  # A week's cards by step, for the study guide's parts (docs/design/study-guide.md, The children's card; Trap 4): none
  # while Get ready is off here.
  def prep_cards_by_step(week_of)
    meeting_prep? ? Array(prep_week_for(week_of)&.cards).index_by(&:step) : {}
  end

  # The week Get ready's pages show and Change a card changes: this one, the Monday where the household lives (Trap 7).
  def prep_week_of
    today.beginning_of_week(:monday)
  end

  # This week's cards are ready, the Monday where the household lives: Home and the sidebar offer Get ready only then
  # (docs/design/meeting-prep.md, Where she finds it).
  def prep_cards_this_week?
    prep_weeks.where(week_of: today.beginning_of_week(:monday)).joins(:cards).exists?
  end

  # Someone can make the cards: the parent's page says so when nobody can (docs/design/meeting-prep.md, The weekly AI job).
  def meeting_prep_owner?
    meeting_prep_owner.present?
  end

  # The children who see the cards as soon as they're made: those of this household who sign in, by name (frame
  # phone-prep-check.png).
  def prep_card_readers
    users.merge(Membership.active.child).joins(:identity).order(:name)
  end

  # The parts of a week with no card whose meeting hasn't passed by +now+, in step order: none before meeting times are
  # set. A week with no PrepWeek misses all five.
  def missing_prep_steps(week_of, now = Time.current)
    return [] unless meeting_times_set?

    carded = PrepWeek::Card.where(prep_week: prep_weeks.where(week_of:)).pluck(:step)
    PrepWeek::Card::STEPS.filter_map { |step, meeting| step unless step.in?(carded) || meeting_in(week_of, meeting).passed?(now) }
  end

  private
    # Under the household's lock: a part still missing a card, an owner who has accepted the AI terms, fewer than the
    # purpose's daily limit of requests today where the household lives, and no other run's claim. Then this run's claim,
    # and the chat, made here so the next run's count sees it. The chat is the owner's, in this household.
    def claim_meeting_prep(week_of)
      steps = missing_prep_steps(week_of).presence or return
      owner = meeting_prep_owner or return :not_allowed
      purpose = Ai::Purpose.find("meeting_prep")
      return if chats.where(purpose: purpose.name, created_at: today.in_time_zone(time_zone)..).count >= purpose.daily_limit

      claim = prep_week_preparations.find_or_initialize_by(week_of:).take or return
      [ claim, chats.create!(user: owner, purpose: purpose.name), steps ]
    end

    # Filled in, and the claim let go, under the lock and only while the claim is still this run's: a run whose claim was
    # taken over saves nothing and leaves the newer claim. A failed request or a reply with no new card lets it go too,
    # so the next daily run tries again. A failed request's chat goes, so it doesn't count towards the daily limit
    # (docs/design/ai.md, safety measure 9); a reply with nothing usable does.
    def ask_for_meeting_prep(claim, chat, steps)
      cards, pages = meeting_prep_from_ai(chat, week_of: claim.week_of, steps:)
      with_lock { prep_weeks.find_or_initialize_by(week_of: claim.week_of).fill_in(cards, pages:, chat:) if claim.release }
    rescue StandardError
      with_lock do
        claim.release
        chat.destroy!
      end
      raise
    end

    # [cards, pages]: the cards for the asked-for parts that pass the checks before saving, and the pages that pass
    # Ai::SourceLink.
    def meeting_prep_from_ai(chat, week_of:, steps:)
      purpose = Ai::Purpose.find(chat.purpose)
      reply = chat.ask_within_purpose(purpose.sent_text(week_of, steps))
      return [ [], [] ] if reply.off_topic?

      copy_check = Ai::CopyCheck.new(citations: reply.sources, overlap_words: purpose.copy_overlap_words, quote_max_words: purpose.quote_max_words)
      [ PrepWeek.cards_from_reply(reply.parsed, steps:, copy_check:),
        Ai::SourceLink.keep(reply.sources, search_results: reply.search_results, allowed_hosts: purpose.allowed_hosts) ]
    end

    # The first active head or adult who has accepted the AI terms: the person who turned Get ready on, then the heads,
    # then the adults, oldest membership first. Never a child, or someone who has left.
    def meeting_prep_owner
      owners = memberships.active.where(role: %w[ head adult ]).by_role.includes(:user).map(&:user).select(&:accepted_ai_terms?)
      owners.find { it.id == meeting_prep&.enabled_by_id } || owners.first
    end
end
