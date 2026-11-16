# One person's note to come back to: a title and a body with scripture links, in a collection, with tags
# (docs/design/notes.md, PersonalNote). Personal and private: it follows the person between households, and nobody
# else ever sees it.
class PersonalNote < ApplicationRecord
  include Collectable, ScriptureLinkable, Taggable

  belongs_to :user

  has_rich_text :body, encrypted: true
  scripture_linkable :body

  normalizes :title, with: -> { it.squish }

  validates :title, presence: true, length: { maximum: 120 }

  scope :preloaded, -> { includes(:collection, :tags, :rich_text_body) }
  scope :recent_first, -> { order(updated_at: :desc, id: :desc) }

  # The scriptures linked in the body, in order and once each, for "Scriptures in this note". Read from the
  # decrypted body, never the database (Traps).
  def scripture_references
    body&.body ? body.body.attachables.grep(Bible::Reference).uniq : []
  end

  private

  # A studies-only collection isn't on Notes' list (Collectable).
  def collection_refusal
    "is only used in Personal study" unless collection.for_notes?
  end
end
