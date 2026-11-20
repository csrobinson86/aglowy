# The claim that a run is asking the AI for a household's week (docs/design/listening-game.md, When it runs).
class ListeningGame::Preparation < ApplicationRecord
  include Claimable

  belongs_to :household
end
