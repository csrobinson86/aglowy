# Kept in one of its person's collections, and found by its title, its collection's name or a tag's name
# (docs/design/personal-study.md, Collection). Personal studies and notes both are. Each says which collections it
# can go in with collection_refusal. matching reads a title column and the Taggable taggings.
module Collectable
  extend ActiveSupport::Concern

  included do
    belongs_to :collection, optional: true

    validate :collection_usable

    # Their bodies are encrypted, so search can't read them (Traps). "#Talk Prep" finds the talk-prep tag, as
    # Tag.normalize makes it; % and _ are plain characters.
    scope :matching, ->(text) do
      term, tag_name = "%#{sanitize_sql_like(text.squish)}%", Tag.normalize(text)
      found = where(arel_table[:title].matches(term)).or(where(collection: Collection.where(Collection.arel_table[:name].matches(term))))
      next found if tag_name.empty?

      tags = Tag.where(Tag.arel_table[:name].matches("%#{sanitize_sql_like(tag_name)}%"))
      found.or(where(id: Tagging.where(taggable_type: polymorphic_name, tag: tags).select(:taggable_id)))
    end
  end

  private

  # Why the collection can't hold this, or nil when it can. Each including model says.
  def collection_refusal = raise(NotImplementedError, "#{self.class} must say which collections it can go in")

  # The database can't check either across tables.
  def collection_usable
    if collection && collection.user_id != user_id
      errors.add(:collection, "isn't one of yours")
    elsif collection && (refusal = collection_refusal)
      errors.add(:collection, refusal)
    end
  end
end
