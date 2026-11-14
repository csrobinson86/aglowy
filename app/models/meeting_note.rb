# One person's notes from one meeting in one week, part by part on the meeting's outline.
# Personal content: it belongs to its author, never to a household (docs/design/meeting-notes.md).
class MeetingNote < ApplicationRecord
  PROGRAM_URL = "https://wol.jw.org/en/wol/meetings/r1/lp-e"

  belongs_to :user
  has_many :parts, -> { order(:position) }, dependent: :destroy
  has_many :gems, -> { order(:position) }, dependent: :delete_all

  enum :kind, %w[ midweek weekend ].index_by(&:itself), validate: true

  # Also applies to lookups, so start_meeting_note finds the note from any day of its week.
  normalizes :week_of, with: -> { it.to_date.beginning_of_week(:monday) }

  validates :week_of, presence: true

  scope :preloaded, -> { includes(:gems, parts: :rich_text_notes) }
  scope :newest_first, -> { order(week_of: :desc, kind: :desc) }

  def outline
    Outline.new(kind: kind, version: outline_version)
  end

  # Builds every part the outline starts with, in order; a repeating part starts with one.
  def build_parts
    outline.parts.each.with_index(1) { |part, position| parts.build(key: part.key, position: position) }
  end

  # The parts the person has written something in. Gems are counted on their own.
  def filled_parts
    parts.select(&:filled?)
  end

  # Each outline section with its filled parts, leaving out sections with none.
  def filled_sections
    outline.sections.filter_map do |section|
      keys = section.parts.map(&:key)
      filled = filled_parts.select { keys.include?(it.key) }
      [ section, filled ] if filled.any?
    end
  end

  # The week's program on wol.jw.org, by ISO week: week 27 of 2026 is 29 June–5 July.
  def program_url
    "#{PROGRAM_URL}/#{week_of.cwyear}/#{week_of.cweek}"
  end

  # "Week of November 16–22, 2026", or "Weekend of November 21–22, 2026".
  def display_week
    weekend? ? "Weekend of #{date_range(week_of + 5, week_of + 6)}" : "Week of #{date_range(week_of, week_of + 6)}"
  end

  private
    def date_range(first, last)
      if first.year != last.year
        "#{first.strftime("%B %-d, %Y")}–#{last.strftime("%B %-d, %Y")}"
      elsif first.month != last.month
        "#{first.strftime("%B %-d")}–#{last.strftime("%B %-d, %Y")}"
      else
        "#{first.strftime("%B %-d")}–#{last.strftime("%-d, %Y")}"
      end
    end
end
