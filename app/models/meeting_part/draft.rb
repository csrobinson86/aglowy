# One AI request for a meeting part and its checked reply (docs/design/meeting-parts.md, MeetingPart::Draft). Each has
# its own chat, and goes with it when the purge deletes the chat 60 days on. Whether it counts toward the person's 15 a
# day is whether it still has its use: failed and flagged drafts give theirs back, and nothing else ever does.
class MeetingPart::Draft < ApplicationRecord
  include Writable

  PURPOSE = "meeting_part".freeze
  REQUEST_MAX = 500
  # The ones that give back their use (docs/design/ai.md, safety measure 9).
  UNCOUNTED_STATUSES = %w[ flagged failed ].freeze

  belongs_to :meeting_part
  belongs_to :user
  # So deleting a part deletes its drafts' chats with them, not at the next purge.
  belongs_to :chat, dependent: :destroy
  # Kept when the draft goes (the database nulls meeting_part_draft_id), so deleting it can't give a request back.
  has_one :use, class_name: "Ai::Use", foreign_key: :meeting_part_draft_id, inverse_of: :meeting_part_draft

  # Keep in step with the meeting_part_drafts_kind_check and meeting_part_drafts_status_check constraints.
  enum :kind, %w[ outline wording ].index_by(&:itself), validate: true
  enum :status, %w[ drafting drafted off_topic flagged failed stopped discarded ].index_by(&:itself), validate: true

  encrypts :request, :result, :revised_result

  normalizes :request, with: -> { it.strip.presence }

  validates :request, length: { maximum: REQUEST_MAX }

  # How many requests a person may make in a day (docs/design/ai.md, safety measure 9).
  def self.daily_limit = Ai::Purpose.find(PURPOSE).daily_limit

  # Keeps its use: a stopped request counts, as the AI may already have been called.
  def stop
    change_status_to "stopped", from: self.class.drafting
  end

  # Only a draft that's done and still counts, so discarding never makes a failed or flagged one count.
  def discard
    change_status_to "discarded", from: self.class.where.not(status: [ "drafting", *UNCOUNTED_STATUSES ])
  end

  # Stops a draft still being written, or discards one that's done, including one whose job finished after it was read.
  def stop_or_discard
    stop || discard
  end

  # About how long the outline takes to say: what the person says, not the aim or the study point advice.
  def spoken_length
    said = result.slice("opening", "question", "close").values + Array(result["points"]).flat_map { it.values_at("heading", "explain") }
    MeetingPart::SpokenLength.new(said.compact.join(" "))
  end

  # The outline as preparation, from our own partial with every field escaped. References stay plain text, linked when
  # the part is saved (docs/design/scripture-links.md).
  def preparation_html
    ApplicationController.render(partial: "meeting_parts/drafts/preparation", locals: { outline: result })
  end

  private
    # Conditional, so a Stop and a job's final write never overwrite each other (docs/design/ai.md, Traps).
    def change_status_to(status, from:)
      (from.where(id: id).update_all(status: status, updated_at: Time.current) == 1).tap { reload }
    end
end
