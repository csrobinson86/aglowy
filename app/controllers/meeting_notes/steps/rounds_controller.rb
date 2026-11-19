# One round of the listening game: four cards, one of them heard in the part (docs/design/listening-game.md, Pages,
# A round). :id is the round's position.
class MeetingNotes::Steps::RoundsController < ApplicationController
  include ListeningRoundScoped

  before_action { set_round(params[:id]) }

  def show
  end
end
