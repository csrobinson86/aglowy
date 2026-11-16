# One person's folder, shared between Personal study and Notes, or used in just one (docs/design/personal-study.md,
# Collection). Each page lists only the collections it uses. Personal: it belongs to the person, never a household.
class Collection < ApplicationRecord
  belongs_to :user
  # The database takes deleted collections' studies out of the folder (on_delete: :nullify), keeping them.
  has_many :personal_studies

  enum :used_in, %w[ both studies notes ].index_by(&:itself), prefix: :used_in, scopes: false, validate: true

  normalizes :name, with: -> { it.squish }

  validates :name, presence: true, length: { maximum: 40 }, uniqueness: { scope: :user_id }
  validate :studies_moved_first, on: :update

  scope :for_studies, -> { where(used_in: %w[ both studies ]) }
  scope :for_notes, -> { where(used_in: %w[ both notes ]) }
  scope :positioned, -> { order(:position) }
  # Each collection with how many studies are in it, as personal_studies_count, for Personal study's list.
  scope :with_personal_studies_count, -> { left_joins(:personal_studies).group(:id).select("collections.*", "COUNT(personal_studies.id) AS personal_studies_count") }

  # Called on a person's collections: user.collections.add(name: "Convention 2027"). Last in their list. Two adds of
  # the same name at once both pass the uniqueness check; the unique index stops the second, which gets the same error.
  def self.add(attributes)
    collection = new(attributes.merge(position: maximum(:position).to_i + 1))
    collection.save
    collection
  rescue ActiveRecord::RecordNotUnique
    collection.errors.add(:name, :taken)
    collection
  end

  # Rename it or change where it's used. A rename that races another to the same name passes the uniqueness check
  # and reaches the unique index, like an add; it gets the same error.
  def revise(attributes)
    update(attributes)
  rescue ActiveRecord::RecordNotUnique
    errors.add(:name, :taken)
    false
  end

  def for_studies? = !used_in_notes?

  private

  # "3 studies are in this collection. Move them first." Taking it out of Personal study would hide them.
  def studies_moved_first
    return unless used_in_changed? && !for_studies?

    count = personal_studies.count
    errors.add(:base, "#{count} #{count == 1 ? "study is" : "studies are"} in this collection. Move #{count == 1 ? "it" : "them"} first.") if count.positive?
  end
end
