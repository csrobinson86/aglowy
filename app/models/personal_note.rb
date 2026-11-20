# One person's note to come back to: a title and a body with scripture links, in a collection, with tags
# (docs/design/notes.md, PersonalNote). Personal and private: it follows the person between households, and nobody
# else ever sees it.
class PersonalNote < ApplicationRecord
  include Collectable, ScriptureLinkable, Taggable

  belongs_to :user
  # The study this is the note of, until the study is deleted (docs/design/notes.md, A Personal study's note).
  belongs_to :personal_study, optional: true
  # The database deletes the pin with the note.
  has_one :pin
  # Deleting it keeps the bookmarks saved from it, with no source (docs/design/bookmarks.md, Bookmark).
  has_many :bookmarks, as: :source, dependent: :nullify
  # Deleting it keeps the calendar times that opened it, opening nothing (docs/design/calendar.md, PersonalTime).
  has_many :personal_times, as: :opens, dependent: :nullify

  has_rich_text :body, encrypted: true
  scripture_linkable :body

  # Casey's nine, after none, in the order the picker and the filter show them (docs/design/notes.md, Colors).
  # Prefixed and without enum scopes: a none scope would clash with Active Record's.
  enum :color, %w[ none yellow orange red pink purple blue green brown gray ].index_with(&:itself), default: "none", prefix: true,
                scopes: false, validate: true

  # The colors Notes' list can be filtered by: all but none, which is "Any color" (docs/design/notes.md, Colors).
  FILTER_COLORS = colors.keys - %w[ none ]

  normalizes :title, with: -> { it.squish }

  TITLE_MAX = 120

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validate :personal_study_is_own, if: :personal_study

  scope :preloaded, -> { includes(:collection, :tags, :rich_text_body) }
  scope :recent_first, -> { order(updated_at: :desc, id: :desc) }
  scope :colored, ->(color) { where(color:) }
  # Newest pin first (docs/design/notes.md, PersonalNote::Pin).
  scope :pinned, -> { joins(:pin).order(PersonalNote::Pin.arel_table[:created_at].desc, id: :desc) }
  scope :unpinned, -> { where.missing(:pin) }

  # The color the note is drawn in: the one chosen, or the saved one while a refused save holds one outside the list,
  # so a class name is only ever built from the list (Traps).
  def drawn_color
    self.class.colors.key?(color) ? color : color_in_database
  end

  def color_name
    drawn_color.humanize
  end

  # Pinning twice finds the first pin: the unique index settles two at once.
  def pin_to_top
    PersonalNote::Pin.create_or_find_by!(personal_note: self)
    reset_pin
  end

  def unpin
    PersonalNote::Pin.where(personal_note: self).delete_all
    reset_pin
  end

  def pinned?
    pin.present?
  end

  # The version an edit form is based on: updated_at, to the microsecond (docs/design/notes.md, A note: the version
  # check). Tagging doesn't move it, so a window's own tag change never makes its form stale.
  def base
    updated_at&.utc&.iso8601(6)
  end

  # Whether a form with this base was rendered from the note as it is now. updated_at only moves forward, so a base
  # that isn't stays stale.
  def based_on?(base)
    base.present? && base == self.base
  end

  # Saves the form's title, color, collection and body, with the references typed in the body linked, only when the
  # form was based on the note as it is now. Under the row lock, which reloads the note, so a save can't land between
  # the check and the write. A stale base raises StaleObjectError and writes nothing, leaving the note as it is now for
  # the form to show again. Tag names are only for "What you wrote": the tag editor saves tags as they're added.
  def revise(attributes, base:)
    with_lock do
      raise ActiveRecord::StaleObjectError.new(self, "revise") unless based_on?(base)

      assign_attributes(attributes.except(:tag_names))
      link_scriptures
      save
    end
  end

  # Saves a new note with the tags its New note editor showed, as typed, all or nothing (docs/design/notes.md, A note:
  # Tags on a new note). Names that normalize the same are one tag, added once. A refused tag (a name that normalizes
  # to nothing, an 11th, the person's 201st) saves nothing and says why in errors; the rollback leaves the note unsaved
  # for the form to show again. Its own savepoint, so the rollback holds inside a caller's transaction too.
  def save_with_tags(tag_names)
    transaction(requires_new: true) do
      raise ActiveRecord::Rollback unless save && tag_names.uniq { Tag.normalize(it) }.all? { add_tag(it) }

      true
    end || false
  end

  # The scriptures linked in the body, in order and once each, for "Scriptures in this note". Read from the
  # decrypted body, never the database (Traps).
  def scripture_references
    body&.body ? body.body.attachables.grep(Bible::Reference).uniq : []
  end

  private

  def add_tag(name)
    tag_with(name, by: user)
  rescue ActiveRecord::RecordInvalid => error
    errors.add(:base, %(Couldn't add the tag "#{name}": #{error.record.errors.full_messages.to_sentence}))
    false
  end

  def personal_study_is_own
    errors.add(:personal_study, "must be your own study") unless personal_study.user_id == user_id
  end

  # A studies-only collection isn't on Notes' list (Collectable).
  def collection_refusal
    "is only used in Personal study" unless collection.for_notes?
  end
end
