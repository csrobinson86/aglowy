# One use of a per-person AI limit (docs/design/personal-study.md, PersonalStudy::Question): the ledger the daily
# count reads. It's made with its question, and deleted only through question.use when the question fails or is
# flagged. Deleting the question keeps it (the database nulls question_id), so it still counts until the purge.
class Ai::Use < ApplicationRecord
  KEEP_FOR = 2.days

  belongs_to :user
  belongs_to :question, class_name: "PersonalStudy::Question", optional: true

  # Keep in step with the ai_uses_purpose_check constraint.
  enum :purpose, Ai::Purpose.names.index_by(&:itself), validate: true

  scope :expired, -> { where(created_at: ...KEEP_FOR.ago) }
  scope :since, ->(time) { where(created_at: time..) }
end
