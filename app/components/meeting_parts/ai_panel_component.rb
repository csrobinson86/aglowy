# "Prepare with AI" on a part's page, for heads and adults on their own part (docs/design/meeting-parts.md, The panel).
# From md up it sits beside the preparation, open; on a phone, "Prepare with AI" opens it in a full-screen dialog. It's
# First use until the person accepts the AI terms, then Start, or Limit reached once they've made the day's requests. A
# saved draft shows its own state: Drafting, Outline or Wording with Ask for a change under it, Off topic (also for
# flagged), or Start with its request kept once it failed, stopped or was discarded. Every state is one Turbo Frame, so
# each answer replaces only the panel.
class MeetingParts::AiPanelComponent < ApplicationComponent
  attr_reader :household, :meeting_part, :user, :draft

  # draft: a saved one shows its state; an unsaved one fills Start (its errors and request show), except a change refused
  # for what was typed, which shows the draft it would change with the change and its error. open: an answer to a
  # request, so on a phone the dialog shows again without scaling in.
  def initialize(household:, meeting_part:, user:, draft: nil, open: false)
    @household = household
    @meeting_part = meeting_part
    @user = user
    @change = draft if draft&.new_record? && draft.revises&.drafted? && draft.errors.attribute_names == [ :request ]
    # A change to a draft that's gone shows Start afresh with why, not what was typed for the change.
    @unrevisable = draft&.new_record? && draft.errors[:revises].any?
    @draft = @change&.revises || (MeetingPart::Draft.new(meeting_part: meeting_part, kind: draft.kind) if @unrevisable) ||
      draft || MeetingPart::Draft.new(meeting_part: meeting_part, kind: "outline")
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

  # A change or sample wording asked for on a draft that's since been discarded, or another tab's stale page.
  def unrevisable? = @unrevisable

  def drafted_heading
    if draft.outline? then "Outline"
    elsif meeting_part.kind_details.talk? then "Sample talk"
    else "Sample conversation"
    end
  end

  # "About 2 min 40 s to say, plus 1 scripture to read" for wording; an outline's scriptures are among its points.
  def time_line
    length = draft.spoken_length
    draft.wording? && length.scriptures.positive? ? "#{length}, plus #{helpers.pluralize(length.scriptures, "scripture")} to read" : length.to_s
  end

  # "20 s", for "This runs about 20 s over".
  def over_by = MeetingPart::SpokenLength.duration(draft.spoken_length.over(meeting_part.minutes))

  # The other speaker's label in sample wording: nil for a talk, which has none.
  def other_speaker = meeting_part.kind_details.other_speaker

  # The outline wording was written from, for "Back to the outline".
  def outline_revised = (draft.revises if draft.wording? && draft.revises&.outline?)

  # Ask for a change: a new draft of the same kind revising this one.
  def change = @change || MeetingPart::Draft.new(kind: draft.kind, revises: draft)

  # Write sample wording: a new wording draft revising this outline.
  def wording_from_outline = MeetingPart::Draft.new(kind: "wording", revises: draft)

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

  def draft_path(of = draft) = household_meeting_part_draft_path(household_id: household, meeting_part_id: meeting_part, id: of)
end
