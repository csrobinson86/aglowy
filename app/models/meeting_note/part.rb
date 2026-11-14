# One part of a meeting note's outline. Everything the person types is encrypted.
class MeetingNote::Part < ApplicationRecord
  belongs_to :meeting_note

  has_rich_text :notes, encrypted: true
  encrypts :title, :speaker

  validates :position, presence: true
  validates :key, inclusion: { in: ->(part) { part.meeting_note&.outline&.parts.to_a.map(&:key) } }
  # Backed by a partial unique index on (meeting_note_id, key) where key <> 'living_part'.
  validates :key, uniqueness: { scope: :meeting_note_id }, unless: :repeats?

  def label
    meeting_note.outline.part(key).label
  end

  def filled?
    title.present? || speaker.present? || notes.present?
  end

  def repeats?
    meeting_note&.outline&.part(key)&.repeats? || false
  end
end
