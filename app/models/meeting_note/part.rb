# One part of a meeting note's outline. Everything the person types is encrypted.
class MeetingNote::Part < ApplicationRecord
  belongs_to :meeting_note

  has_rich_text :notes, encrypted: true
  encrypts :title, :speaker

  validates :position, presence: true
  validates :key, inclusion: { in: ->(part) { part.meeting_note&.outline&.parts.to_a.map(&:key) } }
  # Backed by a partial unique index on (meeting_note_id, key) where key <> 'living_part'.
  validates :key, uniqueness: { scope: :meeting_note_id }, unless: :repeats?
  validate :speaker_only_where_the_outline_has_one

  def label
    meeting_note.outline.part(key).label
  end

  def filled?
    title.present? || speaker.present? || notes.present?
  end

  def repeats?
    meeting_note&.outline&.part(key)&.repeats? || false
  end

  private
    # Only the Public Talk names a speaker (docs/design/meeting-notes.md, MeetingNote::Part).
    def speaker_only_where_the_outline_has_one
      errors.add(:speaker, "isn't asked for in this part") if speaker.present? && !meeting_note&.outline&.part(key)&.field(:speaker)
    end
end
