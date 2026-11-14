# A person's own meeting notes. They're the same in every household the person belongs to, so they're
# reached through Current.user, never Current.household or an id alone (docs/design/meeting-notes.md).
class MeetingNotesController < ApplicationController
  include HouseholdScoped

  def index
    authorize MeetingNote
    @week_of = Current.membership.this_week
    @this_week = Current.user.meeting_notes_for_week(@week_of)
    @earlier = Page.new(Current.user.meeting_notes.where(week_of: ...@week_of).newest_first, number: params[:page])
  end

  # Finds the note for that meeting and week, or starts it, so a second click lands on the same note.
  def create
    authorize MeetingNote
    kind, week_of = meeting_note_params
    redirect_to household_meeting_note_path(id: Current.user.start_meeting_note(kind:, week_of:))
  end

  def show
    @meeting_note = Current.user.meeting_notes.preloaded.find(params[:id])
    authorize @meeting_note
  end

  private

  # Both are required: a missing one is a 400, not a missing keyword.
  def meeting_note_params
    params.expect(meeting_note: %i[ kind week_of ]).require(%i[ kind week_of ])
  end
end
