# This week's listening game, for a head or adult to check before the meeting (docs/design/listening-game.md, Pages,
# This week's game; frame phone-game-check.png): the pages the AI used, and each step's rounds with Change.
class ListeningGamesController < ApplicationController
  include ListeningGameScoped

  def show
    @week_of = Current.household.today.beginning_of_week(:monday)
    @listening_game = Current.household.listening_game_for(@week_of)
  end
end
