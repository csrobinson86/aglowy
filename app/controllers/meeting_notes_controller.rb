# A person's own meeting notes. They're the same in every household the person belongs to, so they're
# reached through Current.user, never Current.household or an id alone (docs/design/meeting-notes.md).
# The one exception is reading: a note shared into this household is also found through
# MeetingNote.shared_with(Current.household), read-only.
class MeetingNotesController < ApplicationController
  include HouseholdScoped

  before_action :set_editable_meeting_note, only: %i[ edit update ]

  def index
    authorize MeetingNote
    @week_of = Current.membership.this_week
    @this_week = Current.user.meeting_notes_for_week(@week_of)
    @shared_count = MeetingNote.shared_with(Current.household).count
    @earlier = Page.new(Current.user.meeting_notes.includes(:sharings).where(week_of: ...@week_of).newest_first, number: params[:page])
  end

  # Finds the note for that meeting and week, or starts it, so a second click lands on the same note.
  def create
    authorize MeetingNote
    kind, week_of = meeting_note_params
    redirect_to household_meeting_note_path(id: Current.user.start_meeting_note(kind:, week_of:))
  end

  # My own note first, else one shared into this household, else 404.
  def show
    @meeting_note = Current.user.meeting_notes.preloaded.find_by(id: params[:id]) ||
      MeetingNote.shared_with(Current.household).preloaded.find(params[:id])
    authorize @meeting_note
  end

  def edit
  end

  # A part or gem id from any other note isn't among this note's, so nested attributes raise RecordNotFound (404).
  # A bad reference shows the form again with everything that was typed.
  def update
    @meeting_note.revise!(note_params)
    redirect_to household_meeting_note_path(id: @meeting_note), notice: "Notes saved."
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_content
  end

  private

  def set_editable_meeting_note
    @meeting_note = Current.user.meeting_notes.preloaded.find(params[:id])
    authorize @meeting_note
  end

  def note_params
    params.expect(meeting_note: [ parts_attributes: [ [ :id, :title, :speaker, :notes, :_destroy ] ], gems_attributes: [ [ :id, :scripture, :insight, :_destroy ] ] ])
  end

  # Both are required: a missing one is a 400, not a missing keyword.
  def meeting_note_params
    params.expect(meeting_note: %i[ kind week_of ]).require(%i[ kind week_of ])
  end
end
