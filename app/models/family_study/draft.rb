# One request to draft a family study with AI (docs/design/family-studies.md, FamilyStudy::Draft). Only the person
# who asked sees it. It's never deleted but with its chat by the 7-day purge, so discarding can't give back a draft.
class FamilyStudy::Draft < ApplicationRecord
  include Writable

  PURPOSE = "family_study_draft".freeze
  LENGTHS = [ 30, 45, 60 ].freeze
  # The ones that use one of the household's drafts for the day (docs/design/ai.md, safety measure 9).
  COUNTED_STATUSES = %w[ drafting drafted off_topic stopped discarded ].freeze

  belongs_to :household
  belongs_to :user
  belongs_to :chat

  # Keep in step with the family_study_drafts_status_check constraint.
  enum :status, %w[ drafting drafted off_topic flagged failed stopped discarded ].index_by(&:itself), validate: true

  encrypts :prompt, :outline

  validates :prompt, presence: true, length: { maximum: 500 }
  validates :length_minutes, inclusion: { in: LENGTHS }

  scope :counted, -> { where(status: COUNTED_STATUSES) }

  # How many drafts a household may make in a day (docs/design/ai.md, safety measure 9).
  def self.daily_limit = Ai::Purpose.find(PURPOSE).daily_limit

  # The draft and its chat, or an unsaved draft with errors: :limit once the household has used the day's drafts.
  # Counted under the household's lock, so two requests at once can't both take the last one.
  def self.start(household:, user:, prompt:, length_minutes:, young_children:)
    draft = household.with_lock do
      new(household:, user:, prompt:, length_minutes:, young_children:, chat: Chat.new(user:, household:, purpose: PURPOSE)).tap do |draft|
        if household.family_study_drafts.left_today.zero?
          draft.errors.add(:base, :limit, message: "You've used today's #{daily_limit} drafts")
        else
          draft.save
        end
      end
    end

    draft.tap { it.write_later if it.persisted? }
  end

  def stop
    change_status_to "stopped", from: self.class.drafting
  end

  # Only a draft that already counts, so discarding never makes a failed or flagged one count.
  def discard
    change_status_to "discarded", from: self.class.counted.where.not(status: "drafting")
  end

  # The outline as study notes, from our own partial with every field escaped. References stay plain text, linked
  # when the study is saved (docs/design/scripture-links.md).
  def notes_html
    ApplicationController.render(partial: "family_studies/drafts/notes", locals: { outline: outline })
  end

  private
    # Conditional, so a Stop and a job's final write never overwrite each other (docs/design/ai.md, Traps).
    def change_status_to(status, from:)
      (from.where(id: id).update_all(status: status, updated_at: Time.current) == 1).tap { reload }
    end
end
