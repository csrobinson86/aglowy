# A page the AI used to write a week's study guide: its title and https URL from the search, through Ai::SourceLink,
# and nothing else (docs/design/ai.md, Link, never copy).
class StudyGuide::Source < ApplicationRecord
  belongs_to :study_guide
end
