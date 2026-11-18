# A page the AI used to find a game's cards: its title and https URL from the search, through Ai::SourceLink, and
# nothing else (docs/design/ai.md, Link, never copy).
class ListeningGame::Source < ApplicationRecord
  belongs_to :listening_game
end
