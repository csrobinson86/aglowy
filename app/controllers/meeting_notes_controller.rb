# A person's own meeting notes. They're the same in every household the person belongs to, so they're
# reached through Current.user, never Current.household or an id alone (docs/design/meeting-notes.md).
class MeetingNotesController < ApplicationController
  include HouseholdScoped

  PER_PAGE = 20

  def index
    authorize MeetingNote
    @week_of = Current.membership.this_week
    @this_week = Current.user.meeting_notes_for_week(@week_of)
    @page = [ params[:page].to_i, 1 ].max
    @notes = Current.user.meeting_notes.where.not(week_of: @week_of).newest_first.offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
  end

  # Finds the note for that meeting and week, or starts it, so a second click lands on the same note.
  def create
    authorize MeetingNote
    redirect_to household_meeting_note_path(id: Current.user.start_meeting_note(**meeting_note_params))
  end

  def show
    @meeting_note = Current.user.meeting_notes.preloaded.find(params[:id])
    authorize @meeting_note
  end

  private

  def meeting_note_params
    params.expect(meeting_note: %i[ kind week_of ]).to_h.symbolize_keys
  end
end
