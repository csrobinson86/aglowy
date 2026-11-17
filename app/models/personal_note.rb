# One person's note to come back to: a title and a body with scripture links, in a collection, with tags
# (docs/design/notes.md, PersonalNote). Personal and private: it follows the person between households, and nobody
# else ever sees it.
class PersonalNote < ApplicationRecord
  include Collectable, ScriptureLinkable, Taggable

  belongs_to :user
  # The database deletes the pin with the note.
  has_one :pin

  has_rich_text :body, encrypted: true
  scripture_linkable :body

  # Like JW Library's (docs/design/notes.md, Colors). Prefixed and without enum scopes: a none scope would clash with
  # Active Record's.
  enum :color, %w[ none yellow green blue purple pink orange ].index_with(&:itself), default: "none", prefix: true,
                scopes: false, validate: true

  # The colors Notes' list can be filtered by: all but none, which is "Any color" (docs/design/notes.md, Colors).
  FILTER_COLORS = colors.keys - %w[ none ]

  normalizes :title, with: -> { it.squish }

  TITLE_MAX = 120

  validates :title, presence: true, length: { maximum: TITLE_MAX }

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
