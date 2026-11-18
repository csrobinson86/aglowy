# One AI request for a meeting part and its checked reply (docs/design/meeting-parts.md, MeetingPart::Draft). Each has
# its own chat, and goes with it when the purge deletes the chat 60 days on. Whether it counts toward the person's 15 a
# day is whether it still has its use: failed and flagged drafts give theirs back, and nothing else ever does.
class MeetingPart::Draft < ApplicationRecord
  include Writable

  PURPOSE = "meeting_part".freeze
  REQUEST_MAX = 500
  # A change asked for under a draft (docs/design/meeting-parts.md, The panel).
  CHANGE_MAX = 300
  # More than this share over the part's time, and the panel says so (Over the time).
  OVER_TIME = 0.15
  # The ones that give back their use (docs/design/ai.md, safety measure 9).
  UNCOUNTED_STATUSES = %w[ flagged failed ].freeze

  belongs_to :meeting_part
  belongs_to :user
  # So deleting a part deletes its drafts' chats with them, not at the next purge.
  belongs_to :chat, dependent: :destroy
  # Kept when the draft goes (the database nulls meeting_part_draft_id), so deleting it can't give a request back.
  has_one :use, class_name: "Ai::Use", foreign_key: :meeting_part_draft_id, inverse_of: :meeting_part_draft
  # The draft a change, or sample wording, was built on: only for the links to it. The job sends the copy in
  # revised_result, and the database nulls this when the purge takes that draft.
  belongs_to :revises, class_name: "MeetingPart::Draft", optional: true

  # Keep in step with the meeting_part_drafts_kind_check and meeting_part_drafts_status_check constraints.
  enum :kind, %w[ outline wording ].index_by(&:itself), validate: true
  enum :status, %w[ drafting drafted off_topic flagged failed stopped discarded ].index_by(&:itself), validate: true

  encrypts :request, :result, :revised_result

  normalizes :request, with: -> { it.strip.presence }

  validates :request, length: { maximum: REQUEST_MAX }
  validates :request, presence: true, length: { maximum: CHANGE_MAX }, if: :change?, on: :create
  validate :revisable, if: :revises, on: :create

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

  # A change asked for under a draft of the same kind, rather than sample wording written from an outline. Read from the
  # copy, which outlasts the draft it was taken from.
  def change?
    revised_result.present? && revised_result.key?("lines") == wording?
  end

  # What the progress lines and the panel call it.
  def kind_label = wording? ? "sample wording" : "outline"

  # "Version 2": one more than the draft it changes, while that draft is kept.
  def version
    revises&.kind == kind ? revises.version + 1 : 1
  end

  # About how long the draft takes to say: what the person says, not an outline's aim or study point advice, and each
  # scripture read aloud, as preparation_html says to.
  def spoken_length
    said, scriptures = wording? ? said_in_wording : said_in_outline
    MeetingPart::SpokenLength.new(said.compact.join(" "), scriptures: scriptures)
  end

  # More than 15% over the part's time. A guide only: it never blocks anything (Trap 6).
  def over_time?
    spoken_length.seconds.to_i > meeting_part.minutes * 60 * (1 + OVER_TIME)
  end

  # The draft as preparation, from our own partial with every field escaped. References stay plain text, linked when
  # the part is saved (docs/design/scripture-links.md).
  def preparation_html
    if wording?
      ApplicationController.render(partial: "meeting_parts/drafts/wording_preparation", locals: { lines: result["lines"], other_speaker: meeting_part.kind_details.other_speaker })
    else
      ApplicationController.render(partial: "meeting_parts/drafts/preparation", locals: { outline: result })
    end
  end

  private
    def said_in_outline
      points = Array(result["points"])
      [ result.slice("opening", "question", "close").values + points.flat_map { it.values_at("heading", "explain") }, points.count { it["scripture"].present? } ]
    end

    def said_in_wording
      lines = result["lines"]
      [ lines.pluck("text"), lines.count { it["read"].present? } ]
    end

    # A drafted draft of the same part: of the same kind for a change, an outline for sample wording.
    def revisable
      return if revises.meeting_part_id == meeting_part_id && revises.drafted? && (revises.kind == kind || revises.outline?)

      errors.add(:revises, :invalid, message: "can't be changed now")
    end

    # Conditional, so a Stop and a job's final write never overwrite each other (docs/design/ai.md, Traps).
    def change_status_to(status, from:)
      (from.where(id: id).update_all(status: status, updated_at: Time.current) == 1).tap { reload }
    end
end
