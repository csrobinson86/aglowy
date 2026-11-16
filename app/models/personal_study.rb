# One person's research on one topic: their questions to the AI, in the study's own chat, and their notes
# (docs/design/personal-study.md, PersonalStudy). Personal: it belongs to the person and follows them between households.
class PersonalStudy < ApplicationRecord
  include ScriptureLinkable, Taggable

  PURPOSE = "personal_study".freeze

  belongs_to :user
  belongs_to :collection, optional: true
  # Made with the study, outside any household, and deleted with it. The database deletes its questions.
  belongs_to :chat, dependent: :destroy, default: -> { Chat.new(user: user, purpose: PURPOSE) }

  has_many :questions, -> { order(:created_at) }, class_name: "PersonalStudy::Question", inverse_of: :personal_study

  has_rich_text :notes, encrypted: true
  scripture_linkable :notes

  normalizes :title, with: -> { it.squish }

  validates :title, presence: true, length: { maximum: 120 }
  validate :collection_for_studies

  scope :preloaded, -> { includes(:collection, :tags, :rich_text_notes) }
  scope :recent_first, -> { order(arel_table[:last_asked_at].desc.nulls_last, updated_at: :desc, id: :desc) }

  # Titles, collection names and tag names. Notes are encrypted, so search can't read them (Traps). "#Talk Prep"
  # finds the talk-prep tag, as Tag.normalize makes it; % and _ are plain characters.
  scope :matching, ->(text) do
    term, tag_name = "%#{sanitize_sql_like(text.squish)}%", Tag.normalize(text)
    found = where(arel_table[:title].matches(term)).or(where(collection: Collection.where(Collection.arel_table[:name].matches(term))))
    next found if tag_name.empty?

    tags = Tag.where(Tag.arel_table[:name].matches("%#{sanitize_sql_like(tag_name)}%"))
    found.or(where(id: Tagging.where(taggable_type: "PersonalStudy", tag: tags).select(:taggable_id)))
  end

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

  private

  # The database can't check either across tables (docs/design/personal-study.md, Collection).
  def collection_for_studies
    if collection && collection.user_id != user_id
      errors.add(:collection, "isn't one of yours")
    elsif collection && !collection.for_studies?
      errors.add(:collection, "is only used in Notes")
    end
  end
end
