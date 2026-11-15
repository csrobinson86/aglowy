# "I heard it!" on one step of a meeting helper note (docs/design/meeting-helper.md, Models). The unique index
# on the note and step keeps it to one mark per step, however many times it's tapped.
class MeetingNote::Mark < ApplicationRecord
  belongs_to :meeting_note

  # A check constraint can't see the note's kind, so the step is validated only.
  validate :step_is_one_of_the_notes

  private
    def step_is_one_of_the_notes
      errors.add(:step, "isn't a step of this meeting") unless meeting_note&.helper_steps&.any? { it.key == step }
    end
end
