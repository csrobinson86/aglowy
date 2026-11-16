# Tagged by its owner with their own tags, which nobody else sees (docs/design/tags.md, Taggable). Views show
# tags_for(Current.user), never tags, so a shared note or goal can't show them to the household.
module Taggable
  extend ActiveSupport::Concern

  included do
    has_many :taggings, as: :taggable, dependent: :delete_all
    has_many :tags, through: :taggings

    scope :tagged_with, ->(tag) { joins(:taggings).where(taggings: { tag_id: tag.id }) }
  end

  # Finds or creates the person's tag and adds it; adding one already there does nothing. Raises RecordInvalid
  # for a name that normalizes to nothing, a tag over a limit, or a thing the person doesn't own, and the
  # savepoint takes back a tag it just created, even when the caller rescues inside its own transaction.
  # Finding first lets a thing at the limit keep its tags.
  def tag_with(text, by:)
    tagging = transaction(requires_new: true) do
      tag = by.tags.find_or_create_by_name!(text)
      taggings.find_by(tag: tag) || taggings.create_or_find_by!(tag: tag)
    end
    tags.reset
    tagging
  end

  # The filtered delete_all leaves loaded taggings alone, so both are reset.
  def untag(tag)
    taggings.where(tag: tag).delete_all
    taggings.reset
    tags.reset
  end

  # Only the owner tags their things.
  def taggable_by?(user)
    user.present? && user_id == user.id
  end

  # All of them for the owner, or for a viewer the thing lets read its tags; none for anyone else.
  def tags_for(user, membership: Current.membership)
    taggable_by?(user) || tags_readable_by?(membership) ? tags : Tag.none
  end

  private

  # Nobody but the owner, unless a taggable says otherwise.
  def tags_readable_by?(membership)
    false
  end
end
