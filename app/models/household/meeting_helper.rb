# The household's switch for the meeting helper for children: it exists while the helper is on. Only created through
# Household#enable_meeting_helper; Household#disable_meeting_helper deletes it (docs/design/meeting-helper.md, Models).
class Household::MeetingHelper < ApplicationRecord
  belongs_to :household
  belongs_to :enabled_by, class_name: "User"

  # Turning it on prepares this week's listening game, once committed so the job's worker sees the switch
  # (docs/design/listening-game.md, When it runs).
  after_create_commit -> { household.prepare_listening_game_later }
end
