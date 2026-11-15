# One step of the meeting helper: the part's picture and prompt, the mark button, and Back and Next
# (docs/design/meeting-helper.md, Pages, A step).
class MeetingNotes::StepsController < ApplicationController
  include MeetingHelperScoped

  def show
    @steps = @meeting_note.helper_steps
    @step = @steps.fetch(params[:id])
  end
end
