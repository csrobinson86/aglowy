# Asking the AI for a person's study guide (docs/design/study-guide.md, The weekly job), under Get ready's claim and
# filling-in rules with the person in place of the household: their lock, their AI terms, their daily limit where they
# live. A run asks only for the steps still missing a part, a group of them at a time, and fills them in, never
# replacing a saved part. Nothing here fetches jw.org or wol.jw.org: the program's address goes into the question as
# text (Trap 1), and only the title and link of each page the AI used are kept.
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
  # person has had their requests for today, or the replies had no usable part for a missing step. :not_allowed, before
  # any claim, chat or request, without accepted AI terms. The claim is taken under the person's lock, which is released
  # before each request goes out.
  def prepare_study_guide(week_of)
    claim = with_lock { claim_study_guide(week_of) }
    claim.is_a?(StudyGuide::Preparation) ? ask_for_study_guide(claim) : claim
  end

  # A week's guide with its parts and sources, or nil while it has none.
  def study_guide_for(week_of)
    study_guides.preloaded.find_by(week_of:)
  end

  # A guide is kept for the week, as the meeting note edit page links to it (docs/design/study-guide.md, Where people
  # find it).
  def study_guide_for?(week_of)
    study_guides.exists?(week_of:)
  end

  # The steps of a week with no part, in the guide's order. A week with no guide misses all nine.
  def missing_study_guide_steps(week_of)
    StudyGuide::Part::STEPS.keys - StudyGuide::Part.where(study_guide: study_guides.where(week_of:)).pluck(:step)
  end

  private
    # Under the person's lock: a step still missing a part, accepted AI terms, and no other run's claim. Then this run's.
    def claim_study_guide(week_of)
      return if missing_study_guide_steps(week_of).none?
      return :not_allowed unless accepted_ai_terms?

      study_guide_preparations.find_or_initialize_by(week_of:).take
    end

    # One request for each group of steps with a step still missing a part, in order (Ai::Purpose::StudyGuide::GROUPS,
    # #432), asking for its missing steps only. Each reply's parts are saved as it comes, so a failed request keeps the
    # earlier groups' parts, and the later groups wait for the next run. The daily limit, or a claim taken over, stops the
    # run. The claim is let go however it ends, while it's still this run's.
    def ask_for_study_guide(claim)
      guide = nil
      Ai::Purpose::StudyGuide::GROUPS.each_value do |group|
        steps = group & missing_study_guide_steps(claim.week_of)
        next if steps.none?

        chat = study_guide_chat(claim) or break
        guide = ask_for_study_guide_steps(claim, chat, steps) || guide
      end
      guide
    ensure
      with_lock { claim.release }
    end

    # Under the person's lock, while the claim is still this run's and they've had fewer than the purpose's daily limit of
    # requests today where they live (Trap 6): the request's chat, made here so the next count sees it. The chat is the
    # person's, in no household.
    def study_guide_chat(claim)
      purpose = Ai::Purpose.find("study_guide")
      with_lock do
        today = chats.where(purpose: purpose.name, created_at: Time.current.in_time_zone(limit_time_zone).beginning_of_day..)
        chats.create!(purpose: purpose.name) unless claim.taken_over? || today.count >= purpose.daily_limit
      end
    end

    # The guide, filled in under the lock and only while the claim is still this run's: a run whose claim was taken over
    # saves nothing and leaves the newer claim. Nil when no part is new. A failed request's chat goes, so it doesn't count
    # towards the daily limit (docs/design/ai.md, safety measure 9); a reply with nothing usable does.
    def ask_for_study_guide_steps(claim, chat, steps)
      parts, pages = study_guide_from_ai(chat, week_of: claim.week_of, steps:)
      with_lock { study_guides.find_or_initialize_by(week_of: claim.week_of).fill_in(parts, pages:, chat:) unless claim.taken_over? }
    rescue StandardError
      with_lock { chat.destroy! }
      raise
    end

    # [parts, pages]: the parts for the asked-for steps that pass the checks before saving, and the pages that pass
    # Ai::SourceLink.
    def study_guide_from_ai(chat, week_of:, steps:)
      purpose = Ai::Purpose.find(chat.purpose)
      reply = chat.ask_within_purpose(purpose.sent_text(week_of, steps), steps:)
      return [ [], [] ] if reply.off_topic?

      copy_check = Ai::CopyCheck.new(citations: reply.sources, overlap_words: purpose.copy_overlap_words, quote_max_words: purpose.quote_max_words)
      [ StudyGuide.parts_from_reply(reply.parsed, steps:, copy_check:),
        Ai::SourceLink.keep(reply.sources, search_results: reply.search_results, allowed_hosts: purpose.allowed_hosts) ]
    end
end
