# One student part a person has been given in Apply Yourself to the Field Ministry: what was assigned, their own
# preparation with scripture links, and the counsel afterwards (docs/design/meeting-parts.md, MeetingPart). Personal:
# it belongs to the person and follows them between households, and nobody else sees it.
class MeetingPart < ApplicationRecord
  include ScriptureLinkable

  SETTINGS = { "house_to_house" => "House to house", "informal_witnessing" => "Informal witnessing", "public_witnessing" => "Public witnessing" }.freeze

  belongs_to :user

  encrypts :topic, :study_point, :assistant, :counsel
  has_rich_text :preparation, encrypted: true
  scripture_linkable :preparation

  normalizes :topic, with: -> { it.strip }
  normalizes :study_point, :assistant, with: -> { it.squish.presence }
  normalizes :setting, :counsel, with: -> { it.strip.presence }

  validates :kind, inclusion: { in: Kind.keys }
  validates :meeting_on, presence: true
  validates :minutes, numericality: { only_integer: true, in: 1..15 }
  validates :setting, inclusion: { in: SETTINGS.keys }, allow_nil: true
  validates :topic, presence: true, length: { maximum: 300 }
  validates :study_point, :assistant, length: { maximum: 80 }
  validates :counsel, length: { maximum: 2000 }

  # today is the date in the person's own zone (User#today).
  scope :coming_up, ->(today) { where(meeting_on: today..).order(:meeting_on, :created_at) }
  scope :earlier, ->(today) { where(meeting_on: ...today).order(meeting_on: :desc, created_at: :desc) }

  def kind_details
    Kind.find(kind)
  end

  def setting_label
    SETTINGS[setting]
  end

  # The Monday of the meeting's week, for the program link and that week's meeting note.
  def week_of
    meeting_on.beginning_of_week(:monday)
  end

  def program_url
    MeetingNote.program_url(week_of)
  end

  # About how long the preparation takes to say, for the time line under its editor.
  def spoken_length
    SpokenLength.new(preparation_text)
  end

  private
    # The words as the editor's own text has them, so spoken_length_controller.js counts the same: a break after each
    # block and no list numbers. ActionText's to_plain_text numbers lists and runs headings and table cells together.
    def preparation_text
      return "" unless preparation.body

      html = preparation.body.render_attachments(with_full_attributes: false, &:to_plain_text).fragment.source
      html.css("h1, h2, h3, h4, h5, h6, p, div, li, td, th, blockquote, pre, br").each { it.add_next_sibling(" ") }
      html.text
    end
end
