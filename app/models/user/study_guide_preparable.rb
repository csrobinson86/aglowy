# Asking the AI for a person's study guide (docs/design/study-guide.md, The weekly job), under Get ready's claim and
# filling-in rules with the person in place of the household: their lock, their AI terms, their daily limit where they
# live. A run asks only for the steps still missing a part and fills them in, never replacing a saved part. Nothing here
# fetches jw.org or wol.jw.org: the program's address goes into the question as text (Trap 1), and only the title and
# link of each page the AI used are kept.
module User::StudyGuidePreparable
  extend ActiveSupport::Concern

  included do
    # Their parts and sources go with them (on_delete: :cascade).
    has_many :study_guides, dependent: :delete_all
    has_many :study_guide_preparations, class_name: "StudyGuide::Preparation", dependent: :delete_all

    # StudyGuide::PrepareJob runs for people in both: the setting on, and a head or adult in an active household. Not
    # preloaded, so study_guide_on? reads the setting at each person's turn, not when their batch was loaded.
    scope :with_study_guide_on, -> { joins(:weekly_study_guide) }
    scope :head_or_adult_somewhere, -> { where(id: Membership.active.where(role: %w[ head adult ]).select(:user_id)) }
  end

  # The parts still missing from this week, the Monday where the person lives (Trap 6), while their study guide is on
  # and they're a head or adult somewhere. Only the current week is asked for, so a week is never retried once it ends.
  def prepare_this_weeks_study_guide
    prepare_study_guide(study_guide_week) if study_guide_on? && may_have_study_guide?
  end

  def prepare_study_guide_later
    StudyGuide::PrepareJob.perform_later(self)
  end

  # The Monday of the person's current week, by limit_time_zone's clock.
  def study_guide_week
    Time.current.in_time_zone(limit_time_zone).to_date.beginning_of_week(:monday)
  end

  # The guide with the parts it saved, or nil when no step is missing a part, another run holds the week's claim, the
  # person has had their requests for today, or the reply had no usable part for a missing step. :not_allowed, before
  # any claim, chat or request, without accepted AI terms. The claim is taken under the person's lock, which is released
  # before the request goes out.
  def prepare_study_guide(week_of)
    claimed = with_lock { claim_study_guide(week_of) }
    claimed.is_a?(Array) ? ask_for_study_guide(*claimed) : claimed
  end

  # A week's guide with its parts and sources, or nil while it has none.
  def study_guide_for(week_of)
    study_guides.preloaded.find_by(week_of:)
  end

  # The steps of a week with no part, in the guide's order. A week with no guide misses all nine.
  def missing_study_guide_steps(week_of)
    StudyGuide::Part::STEPS.keys - StudyGuide::Part.where(study_guide: study_guides.where(week_of:)).pluck(:step)
  end

  private
    # Under the person's lock: a step still missing a part, accepted AI terms, fewer than the purpose's daily limit of
    # requests today where they live (Trap 6), and no other run's claim. Then this run's claim, and the chat, made here so
    # the next run's count sees it. The chat is the person's, in no household.
    def claim_study_guide(week_of)
      steps = missing_study_guide_steps(week_of).presence or return
      return :not_allowed unless accepted_ai_terms?

      purpose = Ai::Purpose.find("study_guide")
      return if chats.where(purpose: purpose.name, created_at: Time.current.in_time_zone(limit_time_zone).beginning_of_day..).count >= purpose.daily_limit

      claim = study_guide_preparations.find_or_initialize_by(week_of:).take or return
      [ claim, chats.create!(purpose: purpose.name), steps ]
    end

    # Filled in, and the claim let go, under the lock and only while the claim is still this run's: a run whose claim was
    # taken over saves nothing and leaves the newer claim. A failed request or a reply with no new part lets it go too,
    # so the next run tries again. A failed request's chat goes, so it doesn't count towards the daily limit
    # (docs/design/ai.md, safety measure 9); a reply with nothing usable does.
    def ask_for_study_guide(claim, chat, steps)
      parts, pages = study_guide_from_ai(chat, week_of: claim.week_of, steps:)
      with_lock { study_guides.find_or_initialize_by(week_of: claim.week_of).fill_in(parts, pages:, chat:) if claim.release }
    rescue StandardError
      with_lock do
        claim.release
        chat.destroy!
      end
      raise
    end

    # [parts, pages]: the parts for the asked-for steps that pass the checks before saving, and the pages that pass
    # Ai::SourceLink.
    def study_guide_from_ai(chat, week_of:, steps:)
      purpose = Ai::Purpose.find(chat.purpose)
      reply = chat.ask_within_purpose(purpose.sent_text(week_of, steps))
      return [ [], [] ] if reply.off_topic?

      copy_check = Ai::CopyCheck.new(citations: reply.sources, overlap_words: purpose.copy_overlap_words, quote_max_words: purpose.quote_max_words)
      [ StudyGuide.parts_from_reply(reply.parsed, steps:, copy_check:),
        Ai::SourceLink.keep(reply.sources, search_results: reply.search_results, allowed_hosts: purpose.allowed_hosts) ]
    end
end
