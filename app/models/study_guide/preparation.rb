# The claim that a run is asking the AI for a person's study guide week (docs/design/study-guide.md, The weekly job),
# held like Get ready's, under the person's lock instead of a household's.
class StudyGuide::Preparation < ApplicationRecord
  include Claimable

  belongs_to :user
end
