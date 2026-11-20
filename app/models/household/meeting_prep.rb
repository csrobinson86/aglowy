# The household's switch for Get ready: it exists while Get ready is on, and only while the meeting helper is. Only
# created through Household#enable_meeting_prep; Household#disable_meeting_prep and #disable_meeting_helper delete it
# (docs/design/meeting-prep.md, Models).
class Household::MeetingPrep < ApplicationRecord
  belongs_to :household
  belongs_to :enabled_by, class_name: "User"

  # Turning it on prepares this week straight away, once committed so the job's worker sees the switch
  # (docs/design/meeting-prep.md, The Settings check box).
  after_create_commit -> { household.prepare_meeting_prep_later }
end
