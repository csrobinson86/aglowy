# "Plan it with AI" beside the Schedule form, for heads and adults (docs/design/family-studies.md, The panel).
# Start shows until "Draft with AI" opens the panel in place; opened, it's First use until the person accepts the AI
# terms, then Describe, or Limit reached once the household has used the day's drafts. A started draft is Drafting.
# Every state is one Turbo Frame, so accepting the terms and starting a draft replace only the panel.
class FamilyStudies::AiPanelComponent < ApplicationComponent
  DEFAULT_LENGTH = 45

  attr_reader :household, :user, :draft

  # draft: the one just started, or one that didn't start (its errors show). open: show the opened panel, not Start.
  def initialize(household:, user:, draft: nil, open: false)
    @household = household
    @user = user
    @draft = draft || FamilyStudy::Draft.new(length_minutes: DEFAULT_LENGTH)
    @open = open
  end

  def open? = @open

  def drafting? = draft.persisted?

  def opened_state
    if !user.accepted_ai_terms? then :terms
    elsif draft.errors.of_kind?(:base, :limit) || drafts_left.zero? then :limit
    else :describe
    end
  end

  def heading
    opened_state == :terms ? "Before you use AI" : "Draft with AI"
  end

  def daily_limit = FamilyStudy::Draft.daily_limit

  def drafts_left
    @drafts_left ||= household.family_study_drafts.left_today
  end

  # "Central Time", from the household's "Central Time (US & Canada)": the day's drafts reset at its midnight.
  def time_zone_name
    household.time_zone.sub(/ \(.+\)\z/, "")
  end

  # Back to this form with the panel open, after the terms are accepted.
  def return_to
    new_household_family_study_path(household_id: household, ai_panel: "open")
  end
end
