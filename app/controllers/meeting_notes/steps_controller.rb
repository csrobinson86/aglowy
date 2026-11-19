# One step of the meeting helper: the part's picture and prompt, the mark button, and Back and Next
# (docs/design/meeting-helper.md, Pages, A step). A step with listening game rounds opens at its round instead
# (docs/design/listening-game.md, Pages, A step).
class MeetingNotes::StepsController < ApplicationController
  include MeetingHelperScoped

  def show
    @steps = @meeting_note.helper_steps
    @step = @steps.fetch(params[:id])

    rounds = Current.household.listening_rounds(@meeting_note.week_of, @step.key).to_a
    redirect_to household_meeting_note_step_round_path(step_id: @step.key, id: @meeting_note.current_round(rounds).position) if rounds.any?
  end
end
