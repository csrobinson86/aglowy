# Her answer for the Congregation Bible Study (docs/design/listening-game.md, Pages, Her answer) or her comment for the
# Watchtower Study (docs/design/meeting-prep.md), written before the meeting. A helper page, on the child's own note.
# Any other step is a 404. Saving goes back to the step, or to the Get ready card she came from.
class MeetingNotes::Steps::AnswersController < ApplicationController
  include MeetingHelperScoped

  before_action :set_step

  def edit
    @answer = @meeting_note.answer || @meeting_note.build_answer
  end

  def update
    @answer = @meeting_note.write_answer(params.expect(answer: %i[ paragraph body ]))

    if @answer.errors.none?
      redirect_to back_to_step_path(@step)
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_step
    @step = @meeting_note.helper_steps.fetch(params[:step_id])
    raise ActiveRecord::RecordNotFound unless @step.answerable?
  end
end
