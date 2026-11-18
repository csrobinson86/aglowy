# One student part a person has been given in Apply Yourself to the Field Ministry: what was assigned, their own
# preparation with scripture links, and the counsel afterwards (docs/design/meeting-parts.md, MeetingPart). Personal:
# it belongs to the person and follows them between households, and nobody else sees it until they share it with a
# household, which reads the part and its preparation, never the counsel.
class MeetingPart < ApplicationRecord
  include ScriptureLinkable, Shareable

  SETTINGS = { "house_to_house" => "House to house", "informal_witnessing" => "Informal witnessing", "public_witnessing" => "Public witnessing" }.freeze

  belongs_to :user
  # After Shareable, so destroying deletes the sharings before these (Shareable#take_back_notifications_of).
  has_many :notifications, as: :subject, dependent: :delete_all
  # Each destroyed with its chat, so deleting a part leaves no AI text behind. Their uses stay and still count.
  has_many :drafts, class_name: "MeetingPart::Draft", dependent: :destroy

  encrypts :topic, :study_point, :assistant, :counsel
  has_rich_text :preparation, encrypted: true
  scripture_linkable :preparation

  normalizes :topic, with: -> { it.strip }
  normalizes :study_point, :assistant, with: -> { it.squish.presence }
  normalizes :setting, :counsel, with: -> { it.strip.presence }

  validates :kind, inclusion: { in: Kind.keys }
  validates :meeting_on, presence: true
  validates :minutes, numericality: { only_integer: true, in: 1..15 }
  validates :setting, inclusion: { in: SETTINGS.keys }, allow_nil: true
  validates :topic, presence: true, length: { maximum: 300 }
  validates :study_point, :assistant, length: { maximum: 80 }
  validates :counsel, length: { maximum: 2000 }

  # today is the date in the person's own zone (User#today).
  scope :coming_up, ->(today) { where(meeting_on: today..).order(:meeting_on, :created_at) }
  scope :earlier, ->(today) { where(meeting_on: ...today).order(meeting_on: :desc, created_at: :desc) }

  def kind_details
    Kind.find(kind)
  end

  def setting_label
    SETTINGS[setting]
  end

  # The Monday of the meeting's week, for the program link and that week's meeting note.
  def week_of
    meeting_on.beginning_of_week(:monday)
  end

  def program_url
    MeetingNote.program_url(week_of)
  end

  # An AI draft, drafting, with its own chat and its use, then written in the background; or an unsaved draft with
  # errors: :not_allowed for anyone but the owner as a head or adult with the AI terms, :limit once they've made the
  # day's requests. Counted under the person's lock, as they can ask from more than one household at once
  # (docs/design/meeting-parts.md, How a request runs). The job is queued once the lock is let go: it's in another
  # database, and a worker could otherwise start before the draft is committed. revises: the draft a change, or sample
  # wording, builds on. Its result is copied under the same lock, read afresh, so the job sends what the person saw even
  # if the purge takes that draft first; the draft refuses one that isn't drafted, of this part and of a kind it can revise.
  def draft(kind:, request:, by:, revises: nil)
    draft = by.with_lock do
      revises&.reload
      Draft.new(meeting_part: self, user: by, kind: kind, request: request, revises: revises, revised_result: revises&.result,
                chat: Chat.new(user: by, purpose: Draft::PURPOSE), use: Ai::Use.new(user: by, purpose: Draft::PURPOSE)).tap do |draft|
        if by != user || !(by.may_prepare_parts_with_ai? && by.accepted_ai_terms?)
          draft.errors.add(:base, :not_allowed, message: "Only the part's owner, as a head or adult with AI drafts turned on, can ask")
        elsif by.part_drafts_left_today.zero?
          draft.errors.add(:base, :limit, message: "You've used today's #{Draft.daily_limit} requests")
        else
          draft.save
        end
      end
    end

    draft.tap { it.write_later if it.persisted? }
  end

  # The person's latest draft of the part while it's being written or waiting to be used, which the panel shows on a
  # reload; nil once it's stopped, discarded or done with.
  def current_draft_for(user)
    drafts.where(user: user).order(:created_at, :id).last&.then { it if it.drafting? || it.drafted? }
  end

  # About how long the preparation takes to say, for the time line under its editor.
  def spoken_length
    SpokenLength.new(preparation_text)
  end

  private
    # The words as the editor's own text has them, so spoken_length_controller.js counts the same: a break after each
    # block and no list numbers. ActionText's to_plain_text numbers lists and runs headings and table cells together.
    def preparation_text
      return "" unless preparation.body

      html = preparation.body.render_attachments(with_full_attributes: false, &:to_plain_text).fragment.source
      html.css("h1, h2, h3, h4, h5, h6, p, div, li, td, th, blockquote, pre, br").each { it.add_next_sibling(" ") }
      html.text
    end
end
