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
  # transaction takes back a tag it just created. Finding first lets a thing at the limit keep its tags.
  def tag_with(text, by:)
    tagging = transaction do
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

  # All of them for the owner, none for anyone else. The membership is for PSTUDY-01, where a head can read
  # a child's personal study under a study AI grant.
  def tags_for(user, membership: Current.membership)
    taggable_by?(user) ? tags : Tag.none
  end
end
