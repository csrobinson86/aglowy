# Her answer for the Congregation Bible Study, typed before the meeting (docs/design/listening-game.md,
# MeetingNote::Answer). Hers, like the rest of the note, and encrypted (Trap 9). The unique index keeps it to one per
# note; the body's length is checked here only, because the database sees the ciphertext.
class MeetingNote::Answer < ApplicationRecord
  belongs_to :meeting_note

  encrypts :body

  # The check constraint keeps the paragraph above 0; the top keeps a typo inside a smallint, as a form error.
  validates :paragraph, numericality: { only_integer: true, greater_than: 0, less_than: 1_000 }
  validates :body, presence: true, length: { maximum: 500 }
end
