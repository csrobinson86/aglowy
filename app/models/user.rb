class User < ApplicationRecord
  has_one :identity, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :households, through: :memberships
  has_many :meeting_notes, dependent: :destroy
  # Personal goals only, by user_id. Family goals they set are the household's (set_by_id).
  has_many :goals, dependent: :destroy
  # Deleting the person deletes the open invitations they sent (invited_by_id is not null).
  has_many :sent_invitations, class_name: "Invitation", foreign_key: :invited_by_id, inverse_of: :invited_by, dependent: :delete_all

  normalizes :name, with: -> { it.squish }

  validates :name, presence: true

  # "Invited by Daniel" (frame members.png).
  def first_name
    name.split.first
  end

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

  # Membership#deactivate calls this under the household's lock, so a step naming only someone who left can
  # still be finished. Done steps keep their assignments and ticks as history (docs/design/goals.md,
  # "Leaving a household"). A person's tick on a named step always has an assignment beside it.
  def leave_open_goal_steps_in(household)
    named_steps = household.goal_steps.where(id: Goal::Step::Assignment.where(user: self).select(:step_id))
    open_steps = named_steps.includes(:assignments, :completions).reject(&:done?)

    Goal::Step::Completion.where(user: self, step: open_steps).delete_all
    Goal::Step::Assignment.where(user: self, step: open_steps).delete_all
  end

  # That week's Life and Ministry and Weekend notes, in that order. One not started yet is a new, unsaved note.
  def meeting_notes_for_week(week_of)
    started = meeting_notes.preloaded.where(week_of: week_of).index_by(&:kind)
    MeetingNote.kinds.keys.map { |kind| started[kind] || MeetingNote.new(kind: kind, week_of: week_of) }
  end
end
