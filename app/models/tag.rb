# One person's tag for their own meeting notes, personal goals, personal studies, notes and bookmarks. Nobody else ever sees it (docs/design/tags.md).
class Tag < ApplicationRecord
  LIMIT = 200

  belongs_to :user
  # The database deletes them with the tag (on_delete: :cascade).
  has_many :taggings
  # What carries it, newest first, for the tag's page. Taggings only ever join the tag's person's own things.
  has_many :meeting_notes, -> { newest_first }, through: :taggings, source: :taggable, source_type: "MeetingNote"
  has_many :goals, -> { order(created_at: :desc, id: :desc) }, through: :taggings, source: :taggable, source_type: "Goal"
  has_many :personal_studies, -> { recent_first }, through: :taggings, source: :taggable, source_type: "PersonalStudy"
  has_many :personal_notes, -> { recent_first }, through: :taggings, source: :taggable, source_type: "PersonalNote"
  has_many :bookmarks, -> { recent_first }, through: :taggings, source: :taggable, source_type: "Bookmark"

  # Normalizing leaves only letters, numbers and hyphens, so the one name it can't make valid is an empty one.
  validates :name, format: { with: /\A[a-z0-9][a-z0-9-]{0,29}\z/, message: "needs at least one letter or number" }
  # A name the person already has doesn't count, so a create that races another to it reaches the unique index.
  validate(on: :create) { errors.add(:base, "You already have #{LIMIT} tags, the most you can have") if user && user.tags.where.not(name: name).count >= LIMIT }

  # Renaming never merges two tags (docs/design/tags.md, Pages and routes). The unique index backs this up.
  validate(on: :update) { name_taken if name_changed? && user.tags.where.not(id: id).exists?(name: name) }

  # Each tag with how many things carry it, as taggings_count, for the tag editor's suggestions.
  scope :with_taggings_count, -> { left_joins(:taggings).group(:id).select("tags.*", "COUNT(taggings.id) AS taggings_count") }
  # Each tag on at least one thing of a type ("MeetingNote"), with how many of those carry it, as taggings_count, for
  # that list's My tags.
  scope :carried_by, ->(taggable_type) { joins(:taggings).where(taggings: { taggable_type: }).group(:id).select("tags.*", "COUNT(taggings.id) AS taggings_count") }

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

  # Normalized like a new tag, so "Field Service" becomes field-service. A rename that races another to the same name
  # passes the check above and reaches the unique index; the rollback leaves the new name on the tag for the message.
  def rename(text)
    update(name: self.class.normalize(text))
  rescue ActiveRecord::RecordNotUnique
    name_taken
    false
  end

  private

  def name_taken = errors.add(:base, "You already have ##{name}.")
end
