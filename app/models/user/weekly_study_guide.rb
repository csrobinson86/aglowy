# The person's study guide setting: it exists while their study guide is on. Only created through
# User#turn_on_study_guide, and deleted by User#turn_off_study_guide (docs/design/study-guide.md, Models).
class User::WeeklyStudyGuide < ApplicationRecord
  belongs_to :user
end
