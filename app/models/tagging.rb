# A person's tag on one of their own things. The database can't check the owner across a polymorphic link,
# so the validation does (docs/design/tags.md, Tagging). Created through Taggable#tag_with.
class Tagging < ApplicationRecord
  LIMIT = 10

  belongs_to :tag
  belongs_to :taggable, polymorphic: true

  validate { errors.add(:taggable, "isn't yours to tag") if tag && taggable && !taggable.taggable_by?(tag.user) }
  validate(on: :create) { errors.add(:base, "This already has #{LIMIT} tags, the most it can have") if taggable && Tagging.where(taggable: taggable).count >= LIMIT }
end
