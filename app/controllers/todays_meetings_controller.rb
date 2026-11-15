# "Today's meeting" in the sidebar: each person's own note for the household's current or next meeting
# (docs/design/meeting-helper.md, The Today's meeting page). show never creates anything, because Turbo
# prefetches links on hover; create starts the note.
class TodaysMeetingsController < ApplicationController
  include HouseholdScoped

  before_action { authorize Current.household, policy_class: TodaysMeetingPolicy }

  # With times set, a note already started for this meeting opens straight away; without, the page asks which it is.
  def show
    @meeting = Current.household.current_or_next_meeting
    @todays_meetings = Current.membership.todays_meetings
    note = @meeting && Current.user.meeting_notes.find_by(kind: @meeting.kind, week_of: @meeting.week_of)
    redirect_to edit_household_meeting_note_path(id: note) if note
  end

  # Only a meeting the page could have offered; anything else is a 404 (Trap 4).
  def create
    kind, week_of = params.expect(meeting_note: %i[ kind week_of ]).require(%i[ kind week_of ])
    raise ActiveRecord::RecordNotFound unless Current.membership.todays_meeting?(kind:, week_of:)

    redirect_to edit_household_meeting_note_path(id: Current.user.start_meeting_note(kind:, week_of:))
  end
end
