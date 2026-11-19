# Changing a round of the household's listening game, in a dialog loaded into the game page's Turbo Frame
# (docs/design/listening-game.md, Pages, Change a round; frame phone-game-change.png). Found through Current.household's
# games, so another household's round is a 404. A refused save shows the dialog again with each reason by its field; a
# saved one closes it and redraws the round.
class ListeningGames::RoundsController < ApplicationController
  include ListeningGameScoped

  before_action :set_round

  def edit
    @change = ListeningGame::Round::Change.new(@round)
  end

  def update
    @change = ListeningGame::Round::Change.new(@round, params.expect(listening_game_round_change: ListeningGame::Round::Change.attribute_names))

    if @change.save(by: Current.user)
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "Round saved." }
        format.html { redirect_to household_listening_game_path, notice: "Round saved.", status: :see_other }
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_round
      @round = ListeningGame::Round.where(listening_game: Current.household.listening_games).includes(:cards).find(params[:id])
      @rounds_in_step = @round.listening_game.rounds.where(step: @round.step).count
    end
end
