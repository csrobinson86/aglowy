# One use of a per-person AI limit (docs/design/personal-study.md, PersonalStudy::Question): the ledger the daily
# count reads. It's made with its question or meeting part draft, and deleted only through its use when that fails or
# is flagged. Deleting the question or draft keeps it (the database nulls the id), so it still counts until the purge.
class Ai::Use < ApplicationRecord
  KEEP_FOR = 2.days

  belongs_to :user
  belongs_to :question, class_name: "PersonalStudy::Question", optional: true
  # Used the same way for meeting part drafts (docs/design/meeting-parts.md, MeetingPart::Draft).
  belongs_to :meeting_part_draft, class_name: "MeetingPart::Draft", optional: true
  # And for daily brief writings (docs/design/daily-brief.md, DailyBrief::Writing).
  belongs_to :daily_brief_writing, class_name: "DailyBrief::Writing", optional: true

  # Keep in step with the ai_uses_purpose_check constraint.
  enum :purpose, Ai::Purpose.names.index_by(&:itself), validate: true

  scope :expired, -> { where(created_at: ...KEEP_FOR.ago) }
  scope :since, ->(time) { where(created_at: time..) }
end
