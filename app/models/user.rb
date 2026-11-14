class User < ApplicationRecord
  has_one :identity, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :households, through: :memberships
  has_many :meeting_notes, dependent: :destroy

  normalizes :name, with: -> { it.squish }

  validates :name, presence: true

  def active_households
    households.merge(Membership.active)
  end

  # Finds this person's note for the meeting that week, or creates it with its parts in the same
  # transaction. The unique index on (user_id, kind, week_of) settles two starts at once.
  def start_meeting_note(kind:, week_of:)
    meeting_notes.create_or_find_by!(kind: kind, week_of: week_of, &:build_parts)
  end

  # Membership#deactivate calls this inside its transaction, so the shares end with the membership.
  def stop_sharing_meeting_notes_with(household)
    MeetingNote::Sharing.where(household: household, meeting_note: meeting_notes).delete_all
  end

  # That week's Life and Ministry and Weekend notes, in that order. One not started yet is a new, unsaved note.
  def meeting_notes_for_week(week_of)
    started = meeting_notes.preloaded.where(week_of: week_of).index_by(&:kind)
    MeetingNote.kinds.keys.map { |kind| started[kind] || MeetingNote.new(kind: kind, week_of: week_of) }
  end
end
