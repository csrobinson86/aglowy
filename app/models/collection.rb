# One person's folder, shared between Personal study and Notes, or used in just one (docs/design/personal-study.md,
# Collection). Each page lists only the collections it uses. Personal: it belongs to the person, never a household.
class Collection < ApplicationRecord
  belongs_to :user
  # The database takes deleted collections' studies and notes out of the folder (on_delete: :nullify), keeping them.
  has_many :personal_studies
  has_many :personal_notes
  # Collections for Notes hold bookmarks too (docs/design/bookmarks.md, Collection). Deleting one keeps them.
  has_many :bookmarks, dependent: :nullify

  enum :used_in, %w[ both studies notes ].index_by(&:itself), prefix: :used_in, scopes: false, validate: true

  normalizes :name, with: -> { it.squish }

  validates :name, presence: true, length: { maximum: 40 }, uniqueness: { scope: :user_id }
  validate :studies_moved_first, :notes_moved_first, on: :update

  scope :for_studies, -> { where(used_in: %w[ both studies ]) }
  scope :for_notes, -> { where(used_in: %w[ both notes ]) }
  scope :positioned, -> { order(:position) }
  # Each collection with how many studies are in it, as personal_studies_count, for Personal study's list.
  scope :with_personal_studies_count, -> { left_joins(:personal_studies).group(:id).select("collections.*", "COUNT(personal_studies.id) AS personal_studies_count") }
  # The same for Notes' list, as personal_notes_count.
  scope :with_personal_notes_count, -> { left_joins(:personal_notes).group(:id).select("collections.*", "COUNT(personal_notes.id) AS personal_notes_count") }
  # The same for the Bookmarks tab, as bookmarks_count.
  scope :with_bookmarks_count, -> { left_joins(:bookmarks).group(:id).select("collections.*", "COUNT(bookmarks.id) AS bookmarks_count") }
  # All three, for Settings → Tags and collections. A subquery each, since joining them would multiply the rows.
  scope :with_contents_counts, -> do
    select("collections.*",
           "(SELECT COUNT(*) FROM personal_notes WHERE personal_notes.collection_id = collections.id) AS personal_notes_count",
           "(SELECT COUNT(*) FROM personal_studies WHERE personal_studies.collection_id = collections.id) AS personal_studies_count",
           "(SELECT COUNT(*) FROM bookmarks WHERE bookmarks.collection_id = collections.id) AS bookmarks_count")
  end

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
  def for_notes? = !used_in_studies?

  private

  # Taking it out of Personal study would hide its studies.
  def studies_moved_first
    moved_first(personal_studies, "study") if used_in_changed? && !for_studies?
  end

  # Taking it out of Notes would hide its notes and bookmarks.
  def notes_moved_first
    return unless used_in_changed? && !for_notes?

    moved_first(personal_notes, "note")
    moved_first(bookmarks, "bookmark")
  end

  # "3 bookmarks are in this collection. Move them first."
  def moved_first(records, noun)
    count = records.count
    errors.add(:base, "#{count} #{noun.pluralize(count)} #{count == 1 ? "is" : "are"} in this collection. Move #{count == 1 ? "it" : "them"} first.") if count.positive?
  end
end
