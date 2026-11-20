# The claim that a run is asking the AI for a household's Get ready week (docs/design/meeting-prep.md, The weekly AI
# job), held like the listening game's.
class PrepWeek::Preparation < ApplicationRecord
  include Claimable

  belongs_to :household
end
