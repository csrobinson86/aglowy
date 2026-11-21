# A step's drawing (docs/design/meeting-helper.md, Pages, Draw and A drawing's image). Editing and saving are helper
# pages, on the child's own note; from Get ready's Draw it!, All done goes back to the card. The image itself isn't
# (Trap 1): anyone who may read the note gets it, the author or a member it's shared with, even after the helper is
# turned off.
class MeetingNotes::Steps::DrawingsController < ApplicationController
  include MeetingHelperScoped
  include ActiveStorage::SetCurrent

  skip_before_action :authorize_meeting_helper, :set_meeting_note, only: :show
  before_action :set_step, only: %i[ edit update ]

  # The same lookup as MeetingNotesController#show, then a redirect to the storage service's URL, which expires
  # in five minutes (gotcha 22).
  def show
    meeting_note = Current.user.meeting_notes.find_by(id: params[:meeting_note_id]) ||
      MeetingNote.shared_with(Current.household).find(params[:meeting_note_id])
    authorize meeting_note, :show?

    # Production storage will be another host (the deploy epic).
    redirect_to meeting_note.drawings.find_by!(step: params[:step_id]).image.url, allow_other_host: true
  end

  def edit
  end

  def update
    @drawing = @meeting_note.draw(@step.key, params.expect(drawing: [ :image ])[:image])

    if @drawing.errors.none?
      redirect_to back_to_step_path(@step)
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_step
    @step = @meeting_note.helper_steps.fetch(params[:step_id])
  end
end
