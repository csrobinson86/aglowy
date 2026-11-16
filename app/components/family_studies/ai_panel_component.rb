# "Plan it with AI" beside the Schedule form, for heads and adults (docs/design/family-studies.md, The panel).
# Start shows until "Draft with AI" opens the panel in place; opened, it's First use until the person accepts the AI
# terms, then Describe, or Limit reached once the household has used the day's drafts. A saved draft shows its own
# state: Drafting, Draft, Off topic (also for flagged), or Describe with its text kept once it failed, stopped or
# was discarded. Every state is one Turbo Frame, so each answer, and the job's checked result, replaces only the panel.
class FamilyStudies::AiPanelComponent < ApplicationComponent
  DEFAULT_LENGTH = 45

  attr_reader :household, :user, :draft, :from_study

  # draft: a saved one shows its state; an unsaved one fills Describe (its errors and text show). from_study: the
  # personal study whose prompt Describe starts with when there's no draft. open: show the opened panel, not Start.
  def initialize(household:, user:, draft: nil, from_study: nil, open: false)
    @household = household
    @user = user
    @from_study = from_study
    @draft = draft || FamilyStudy::Draft.new(length_minutes: DEFAULT_LENGTH, prompt: from_study&.family_study_prompt)
    @open = open
  end

  def open? = @open

  # A draft that exists was asked for with the terms accepted, so its state shows first.
  def opened_state
    if draft.persisted? && (draft.drafting? || draft.drafted?) then draft.status.to_sym
    elsif draft.persisted? && (draft.off_topic? || draft.flagged?) then :refused
    elsif !user.accepted_ai_terms? then :terms
    elsif draft.errors.of_kind?(:base, :limit) || drafts_left.zero? then :limit
    else :describe
    end
  end

  def heading
    case opened_state
    when :terms then "Before you use AI"
    when :drafting then "Drafting with AI"
    when :drafted then "AI draft"
    else "Draft with AI"
    end
  end

  # The provider failed or the checks left too little (docs/design/family-studies.md, The panel).
  def failed? = draft.persisted? && draft.failed?

  # “Trusting Jehovah when we feel…” · about 45 minutes · young children
  def request_summary
    [ "From “#{draft.prompt.truncate(30, separator: " ", omission: "…")}”", "about #{draft.length_minutes} minutes",
      ("young children" if draft.young_children?) ].compact.join(" · ")
  end

  # What "Use this draft" put in the form (frame ai-draft-added.png).
  def added_summary
    links = draft.sources.size
    added = links.zero? ? "The topic and notes" : "The topic, notes and #{helpers.pluralize(links, "link")} from jw.org and wol.jw.org"
    "#{added} are now in the form. Change anything you like before you schedule."
  end

  # "jw.org" for www.jw.org, as each source shows beside its title.
  def host(url)
    URI(url).host.delete_prefix("www.")
  end

  def daily_limit = FamilyStudy::Draft.daily_limit

  def drafts_left
    @drafts_left ||= household.family_study_drafts.left_today
  end

  # "Central Time", from the household's "Central Time (US & Canada)": the day's drafts reset at its midnight.
  def time_zone_name
    household.time_zone.sub(/ \(.+\)\z/, "")
  end

  # Back to this form with the panel open, and the study still filled in, after the terms are accepted.
  def return_to
    new_household_family_study_path(household_id: household, ai_panel: "open", from_study: from_study&.id)
  end

  def drafts_path = household_family_study_drafts_path(household_id: household)

  def draft_path = household_family_study_draft_path(household_id: household, id: draft)
end
