# A round of the listening game on one of the helper's steps (docs/design/listening-game.md, Pages): the household's
# game for the note's week, through Current.household, and the helper's own rules for who may play. A round the step
# doesn't have is a 404.
module ListeningRoundScoped
  extend ActiveSupport::Concern

  included do
    include MeetingHelperScoped
  end

  private

  def set_round(position)
    @steps = @meeting_note.helper_steps
    @step = @steps.fetch(params[:step_id])
    @rounds = Current.household.listening_rounds(@meeting_note.week_of, @step.key).to_a
    @round = @rounds.find { it.position.to_s == position } or raise ActiveRecord::RecordNotFound
  end
end
