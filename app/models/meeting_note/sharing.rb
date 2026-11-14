# A note shared, read-only, with one household. Only created through MeetingNote#share_with.
class MeetingNote::Sharing < ApplicationRecord
  belongs_to :meeting_note
  belongs_to :household
end
