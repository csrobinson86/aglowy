# One person's tag for their own meeting notes and personal goals. Nobody else ever sees it (docs/design/tags.md).
class Tag < ApplicationRecord
  LIMIT = 200

  belongs_to :user
  # The database deletes them with the tag (on_delete: :cascade).
  has_many :taggings

  # Normalizing leaves only letters, numbers and hyphens, so the one name it can't make valid is an empty one.
  validates :name, format: { with: /\A[a-z0-9][a-z0-9-]{0,29}\z/, message: "needs at least one letter or number" }
  # A name the person already has doesn't count, so a create that races another to it reaches the unique index.
  validate(on: :create) { errors.add(:base, "You already have #{LIMIT} tags, the most you can have") if user && user.tags.where.not(name: name).count >= LIMIT }

  # Each tag with how many things carry it, as taggings_count, for the tag editor's suggestions.
  scope :with_taggings_count, -> { left_joins(:taggings).group(:id).select("tags.*", "COUNT(taggings.id) AS taggings_count") }

  # "Talk Prep", "#talk_prep" and " talk-prep " are all talk-prep. "###" is "", which is invalid.
  def self.normalize(text)
    text.to_s.strip.delete_prefix("#").downcase.gsub(/[\s_]+/, "-").gsub(/[^a-z0-9-]/, "").sub(/\A-+/, "").first(30)
  end

  # Called on a person's tags: user.tags.find_or_create_by_name!("Ministry"). Finding first means a person at the limit
  # can still use a tag they have; create_or_find_by! leans on the unique index, so two creates at once make one tag.
  def self.find_or_create_by_name!(text)
    name = normalize(text)
    find_by(name: name) || create_or_find_by!(name: name)
  end
end
