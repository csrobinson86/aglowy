# "Today's meeting" in the sidebar: each person's own note for the household's current or next meeting
# (docs/design/meeting-helper.md, The Today's meeting page). show never creates anything, because Turbo
# prefetches links on hover; create starts the note. A child with the meeting helper gets its layout and
# its first step instead of the note's edit page.
class TodaysMeetingsController < ApplicationController
  include HouseholdScoped

  layout -> { meeting_helper? ? "meeting_helper" : "household" }

  before_action { authorize Current.household, policy_class: TodaysMeetingPolicy }
  before_action { request.variant = :meeting_helper if meeting_helper? }

  # With times set, a note already started for this meeting opens straight away; without, the page asks which it is.
  def show
    @meeting = Current.household.current_or_next_meeting
    @todays_meetings = Current.membership.todays_meetings
    note = @meeting && Current.user.meeting_notes.find_by(kind: @meeting.kind, week_of: @meeting.week_of)
    redirect_to note_path(note) if note
  end

  # Only a meeting the page could have offered; anything else is a 404 (Trap 4).
  def create
    kind, week_of = params.expect(meeting_note: %i[ kind week_of ]).require(%i[ kind week_of ])
    raise ActiveRecord::RecordNotFound unless Current.membership.todays_meeting?(kind:, week_of:)

    redirect_to note_path(Current.user.start_meeting_note(kind:, week_of:))
  end

  private
    def meeting_helper?
      return @meeting_helper if defined?(@meeting_helper)

      @meeting_helper = MeetingHelperPolicy.new(pundit_user, Current.household).show?
    end

    # The note's first step for a child with the helper, its edit page for everyone else.
    def note_path(note)
      if meeting_helper?
        household_meeting_note_step_path(meeting_note_id: note, id: note.helper_steps.first.key)
      else
        edit_household_meeting_note_path(id: note)
      end
    end
end
