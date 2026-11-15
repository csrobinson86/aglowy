# "I heard it!" on a step, and tapping again to undo it (docs/design/meeting-helper.md, Pages, Mark).
# Answers with a Turbo Stream that swaps the mark button; without Turbo, back to the step.
class MeetingNotes::Steps::MarksController < ApplicationController
  include MeetingHelperScoped

  before_action :set_step

  def create
    @meeting_note.mark(@step.key)
    respond_with_mark
  end

  def destroy
    @meeting_note.unmark(@step.key)
    respond_with_mark
  end

  private

  def set_step
    @step = @meeting_note.helper_steps.fetch(params[:step_id])
  end

  def respond_with_mark
    respond_to do |format|
      format.turbo_stream { render :mark }
      format.html { redirect_to household_meeting_note_step_path(meeting_note_id: @meeting_note, id: @step.key) }
    end
  end
end
