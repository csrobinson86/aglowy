# Tapping a card in a round (docs/design/listening-game.md, Pages, Tap a card). The answer makes a find; any other card
# saves nothing and says "Listen again". Both answer with a Turbo Stream that redraws the round; without Turbo, back to
# the round. A card that isn't in the round is a 404.
class MeetingNotes::Steps::Rounds::FindsController < ApplicationController
  include ListeningRoundScoped

  before_action { set_round(params[:round_id]) }

  def create
    @card = @round.cards.find(params.expect(:card))
    @meeting_note.find_card(@card)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to household_meeting_note_step_round_path(meeting_note_id: @meeting_note, step_id: @step.key, id: @round.position) }
    end
  end
end
