# A part shared, read-only, with one household. Only created through MeetingPart#share_with.
class MeetingPart::Sharing < ApplicationRecord
  belongs_to :meeting_part
  belongs_to :household
end
