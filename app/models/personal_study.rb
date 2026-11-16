# One person's research on one topic: their questions to the AI, in the study's own chat, and their notes
# (docs/design/personal-study.md, PersonalStudy). Personal: it belongs to the person and follows them between households.
class PersonalStudy < ApplicationRecord
  include Collectable, ScriptureLinkable, Taggable

  PURPOSE = "personal_study".freeze

  belongs_to :user
  # Made with the study, outside any household, and deleted with it. The database deletes its questions.
  belongs_to :chat, dependent: :destroy, default: -> { Chat.new(user: user, purpose: PURPOSE) }

  has_many :questions, -> { order(:created_at) }, class_name: "PersonalStudy::Question", inverse_of: :personal_study

  has_rich_text :notes, encrypted: true
  scripture_linkable :notes

  normalizes :title, with: -> { it.squish }

  validates :title, presence: true, length: { maximum: 120 }

  scope :preloaded, -> { includes(:collection, :tags, :rich_text_notes) }
  scope :recent_first, -> { order(arel_table[:last_asked_at].desc.nulls_last, updated_at: :desc, id: :desc) }

  # The question, asking, with its use, then answered in the background; or an unsaved question with errors: :limit
  # once the person has asked the day's questions, :not_allowed for anyone but the study's owner or without AI access
  # or the AI terms. Counted under the person's lock, as they can ask from more than one household at once
  # (docs/design/ai.md, safety measure 9).
  def ask(prompt, by:, young_reader: false)
    question = by.with_lock do
      PersonalStudy::Question.new(personal_study: self, user: by, prompt: prompt, young_reader: young_reader, use: Ai::Use.new(user: by, purpose: PURPOSE)).tap do |question|
        if by != user
          question.errors.add(:base, :not_allowed, message: "Only the study's owner can ask in it")
        elsif by.study_questions_left_today.zero?
          question.errors.add(:base, :limit, message: "You've asked #{PersonalStudy::Question.daily_limit} questions today. You can ask again after midnight.")
        elsif !(by.may_ask_study_ai? && by.accepted_ai_terms?)
          question.errors.add(:base, :not_allowed, message: "Personal study with AI isn't turned on for you")
        elsif question.save
          touch :last_asked_at
        end
      end
    end

    question.tap { it.answer_later if it.persisted? }
  end

  # The questions asked, oldest first. A question ask refused is left in the loaded list (has_many_inversing), so
  # it's never shown as asked.
  def conversation
    questions.select(&:persisted?)
  end

  # Every page linked across the study's answers, once each: [{ "url", "title" }] (The study page, Sources in this study).
  def sources
    conversation.select(&:answered?).flat_map(&:sources).uniq { it["url"] }
  end

  # What "Plan a family study from this" puts in the AI panel's Describe box: "<title>: <last question>", cut to the
  # box's length (docs/design/personal-study.md, Plan a family study from this).
  def family_study_prompt
    [ title, questions.last&.prompt ].compact.join(": ").truncate(FamilyStudy::Draft::PROMPT_MAX, separator: " ")
  end

  private

  # A head who can read the child's studies sees their tags on them (ChildStudyPolicy). Never the child's meeting
  # notes or goals, whose tags stay owner-only (docs/design/personal-study.md, Traps).
  def tags_readable_by?(membership)
    child = membership && user.memberships.find_by(household_id: membership.household_id)
    child.present? && ChildStudyPolicy.new(membership, child).show?
  end

  # A notes-only collection isn't on Personal study's list (Collectable).
  def collection_refusal
    "is only used in Notes" unless collection.for_studies?
  end
end
