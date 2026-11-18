# "Prepare with AI" on a part's page, for heads and adults on their own part (docs/design/meeting-parts.md, The panel).
# From md up it sits beside the preparation, open; on a phone, "Prepare with AI" opens it in a full-screen dialog. It's
# First use until the person accepts the AI terms, then Start, or Limit reached once they've made the day's requests. A
# saved draft shows its own state: Drafting, Outline, Off topic (also for flagged), or Start with its request kept once
# it failed, stopped or was discarded. Every state is one Turbo Frame, so each answer replaces only the panel.
class MeetingParts::AiPanelComponent < ApplicationComponent
  attr_reader :household, :meeting_part, :user, :draft

  # draft: a saved one shows its state; an unsaved one fills Start (its errors and request show). open: an answer to a
  # request, so on a phone the dialog shows again without scaling in.
  def initialize(household:, meeting_part:, user:, draft: nil, open: false)
    @household = household
    @meeting_part = meeting_part
    @user = user
    @draft = draft || MeetingPart::Draft.new(meeting_part: meeting_part, kind: "outline")
    @open = open
  end

  def open? = @open

  # A draft that exists was asked for with the terms accepted, so its state shows first.
  def state
    if draft.persisted? && (draft.drafting? || draft.drafted?) then draft.status.to_sym
    elsif draft.persisted? && (draft.off_topic? || draft.flagged?) then :refused
    elsif !user.accepted_ai_terms? then :terms
    elsif draft.errors.of_kind?(:base, :limit) || left_today.zero? then :limit
    else :start
    end
  end

  def heading
    case state
    when :terms then "Before you use AI"
    when :drafting then "Drafting with AI"
    else "Prepare with AI"
    end
  end

  # The provider failed, the queue refused the job, or the checks left too little.
  def failed? = draft.persisted? && draft.failed?

  def daily_limit = MeetingPart::Draft.daily_limit

  def left_today
    @left_today ||= user.part_drafts_left_today
  end

  # "Central Time", from "Central Time (US & Canada)": the day's requests reset at midnight where the person is.
  def time_zone_name
    user.limit_time_zone.sub(/ \(.+\)\z/, "")
  end

  # "jw.org" for www.jw.org, as each page shows beside its title.
  def host(url)
    URI(url).host.delete_prefix("www.")
  end

  # Back to the part after the terms are accepted.
  def return_to = household_meeting_part_path(household_id: household, id: meeting_part)

  def drafts_path = household_meeting_part_drafts_path(household_id: household, meeting_part_id: meeting_part)

  def draft_path = household_meeting_part_draft_path(household_id: household, meeting_part_id: meeting_part, id: draft)
end
