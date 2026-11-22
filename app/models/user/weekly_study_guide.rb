# The person's study guide setting: it exists while their study guide is on. Only created through
# User#turn_on_study_guide, and deleted by User#turn_off_study_guide (docs/design/study-guide.md, Models).
class User::WeeklyStudyGuide < ApplicationRecord
  belongs_to :user

  # Turning it on prepares this week straight away, once committed so the job's worker sees the setting
  # (docs/design/study-guide.md, The Settings section).
  after_create_commit -> { user.prepare_study_guide_later }
end
