# One person's research on one topic: their notes now, and a conversation with the AI from the next story
# (docs/design/personal-study.md, PersonalStudy). Personal: it belongs to the person and follows them between households.
class PersonalStudy < ApplicationRecord
  include ScriptureLinkable, Taggable

  belongs_to :user
  belongs_to :collection, optional: true

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
