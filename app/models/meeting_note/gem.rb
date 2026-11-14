# A Spiritual Gem: a scripture reference plus what the person found in it, on a Life and Ministry note.
# The reference isn't personal and stays plain for Bible order; the insight is encrypted.
class MeetingNote::Gem < ApplicationRecord
  belongs_to :meeting_note

  encrypts :insight

  validates :position, presence: true
  validate :scripture_is_a_reference, :meeting_note_is_midweek

  # Keeps the reference as typed and fills the book, chapter and verses from it, or clears them.
  def scripture=(reference)
    super
    parsed = Scripture.parse(reference)
    self.book_number = parsed&.book_number
    self.chapter = parsed&.chapter
    self.verse_start = parsed&.verse_start
    self.verse_end = parsed&.verse_end
  end

  # The reference written out in full, as the read view shows it: "Phil 4:6, 7" is "Philippians 4:6-7".
  def reference
    Scripture.new(book_number:, chapter:, verse_start:, verse_end:)
  end

  private
    def scripture_is_a_reference
      errors.add(:scripture, "Use a reference like Isaiah 41:10.") unless book_number && chapter
    end

    # Gems are part of the Life and Ministry outline. A check constraint can't see the note's kind, so this is validated only.
    def meeting_note_is_midweek
      errors.add(:meeting_note, "must be a Life and Ministry note") if meeting_note&.weekend?
    end
end
