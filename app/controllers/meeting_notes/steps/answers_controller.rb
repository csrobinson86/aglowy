# Her answer for the Congregation Bible Study, written before the meeting (docs/design/listening-game.md, Pages, Her
# answer). A helper page, on the child's own note. Any other step is a 404. Saving goes back to the step.
class MeetingNotes::Steps::AnswersController < ApplicationController
  include MeetingHelperScoped

  before_action :set_step

  def edit
    @answer = @meeting_note.answer || @meeting_note.build_answer
  end

  def update
    @answer = @meeting_note.write_answer(params.expect(answer: %i[ paragraph body ]))

    if @answer.errors.none?
      redirect_to household_meeting_note_step_path(meeting_note_id: @meeting_note, id: @step.key)
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
