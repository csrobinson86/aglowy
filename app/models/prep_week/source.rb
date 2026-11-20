# A page the AI used to write a week's Get ready cards: its title and https URL from the search, through
# Ai::SourceLink, and nothing else (docs/design/ai.md, Link, never copy).
class PrepWeek::Source < ApplicationRecord
  belongs_to :prep_week
end
