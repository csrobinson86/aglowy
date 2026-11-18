# One AI writing of a daily brief and its checked reply (docs/design/daily-brief.md, DailyBrief::Writing). Each has its
# own chat, and goes with it when the purge deletes the chat 60 days on. Whether it counts toward the person's 3 a day is
# whether it still has its use: failed and flagged writings give theirs back, and nothing else ever does.
class DailyBrief::Writing < ApplicationRecord
  include Writable

  PURPOSE = "daily_brief".freeze
  # The ones that give back their use (docs/design/ai.md, safety measure 9).
  UNCOUNTED_STATUSES = %w[ flagged failed ].freeze
  # The ones the page explains with a Banner, over the parts from the plan.
  UNWRITTEN_STATUSES = %w[ failed flagged off_topic stopped ].freeze

  belongs_to :daily_brief
  # So deleting a brief deletes its writings' chats with them, not at the next purge.
  belongs_to :chat, dependent: :destroy
  # Kept when the writing goes (the database nulls daily_brief_writing_id), so deleting it can't give a request back.
  has_one :use, class_name: "Ai::Use", foreign_key: :daily_brief_writing_id, inverse_of: :daily_brief_writing

  # Keep in step with the daily_brief_writings_status_check constraint.
  enum :status, %w[ writing written off_topic flagged failed stopped ].index_by(&:itself), validate: true

  encrypts :result

  delegate :user, to: :daily_brief

  # How many writings a person may start in a day (docs/design/ai.md, safety measure 9).
  def self.daily_limit = Ai::Purpose.find(PURPOSE).daily_limit

  # Keeps its use: a stopped request counts, as the AI may already have been called. Conditional, so a Stop and a job's
  # final write never overwrite each other (docs/design/ai.md, Traps).
  def stop
    (self.class.writing.where(id: id).update_all(status: "stopped", updated_at: Time.current) == 1).tap { reload }
  end

  # The section's checked fields, or nil when the reply had none or the checks left nothing.
  def section(name)
    result&.dig(name.to_s)
  end
end
