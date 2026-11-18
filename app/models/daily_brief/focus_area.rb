# One part of a person's life the daily brief gives a short section every day: "As a husband", "Qualities to focus
# on" (docs/design/daily-brief.md, DailyBrief::FocusArea). What the person typed is encrypted.
class DailyBrief::FocusArea < ApplicationRecord
  MAX = 6

  belongs_to :plan
  belongs_to :goal, optional: true

  # Keep in step with daily_brief_focus_areas_kind_check. One quality and one appreciation per plan, by partial
  # unique indexes.
  enum :kind, %w[ role quality appreciation ].index_by(&:itself), validate: true

  encrypts :name, :gives

  normalizes :name, with: -> { it.squish }
  normalizes :gives, with: -> { it.strip }
  normalizes :scriptures, with: -> { it.squish.presence }

  validates :name, presence: true, length: { maximum: 60 }
  validates :gives, presence: true, length: { maximum: 200 }
  validates :scriptures, length: { maximum: 120 }
  validate :scriptures_parse
  validate :room_on_the_plan, on: :create
  validate :one_of_its_kind, unless: :role?

  before_create :take_next_position, unless: :position
  after_destroy :remove_topics

  # "Ephesians 5:25; Proverbs 5:18", each shown as a link.
  def scripture_references
    scripture_texts.filter_map { Bible::Reference.parse(it) }
  end

  private
    def scripture_texts
      scriptures.to_s.split(";").map(&:strip).compact_blank
    end

    def scriptures_parse
      unparsed = scripture_texts.reject { Bible::Reference.parse(it) }
      errors.add(:scriptures, "has a reference that isn't a Bible verse: #{unparsed.to_sentence}") if unparsed.any?
    end

    def room_on_the_plan
      errors.add(:base, "You can have six focus areas at most") if plan && plan.focus_areas.count >= MAX
    end

    # The partial unique indexes have the last word; this gives the form a reason.
    def one_of_its_kind
      errors.add(:kind, "You already have #{kind == "quality" ? "a quality" : "an appreciation"} focus area") if
        plan && plan.focus_areas.where(kind:).where.not(id:).exists?
    end

    # After the last, so a new one goes at the end of the list and the brief.
    def take_next_position
      self.position = (plan.focus_areas.maximum(:position) || -1) + 1
    end

    # Its topics in the week are keyed by its id. Encrypted, so each day is rewritten rather than updated in SQL: locked
    # and read again first, in wday order, so a delete of another focus area at the same time can't write back a day
    # read before this one's key came off.
    def remove_topics
      plan.days.each do |day|
        day.with_lock { day.update!(topics: day.topics.except(id)) if day.topics.key?(id) }
      end
    end
end
