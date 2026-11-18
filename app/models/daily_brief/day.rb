# One weekday's row of a person's plan: what the day's brief draws on (docs/design/daily-brief.md, DailyBrief::Day). An
# empty box means the brief chooses. Seven per plan, made with it; all of it encrypted.
class DailyBrief::Day < ApplicationRecord
  TOPIC_MAX = 120

  belongs_to :plan

  encrypts :reading, :examples, :topics

  normalizes :reading, :examples, with: -> { it.squish.presence }
  # The day's topic for each focus area, by the focus area's id.
  normalizes :topics, with: -> { it.transform_values { |topic| topic.to_s.squish }.compact_blank }

  validates :wday, inclusion: { in: 0..6 }
  validates :reading, length: { maximum: 120 }
  validates :examples, length: { maximum: 200 }
  validate :topics_short
  validate :topics_for_own_focus_areas

  # Saves what the day's dialog sent, or keeps it unsaved with the reasons. Under the day's lock, the one a focus area
  # takes to take its topics off, so a topic for a focus area deleted at the same time is either refused or taken off.
  def revise(attributes)
    with_lock { update(attributes) }
  end

  def topic_for(focus_area)
    topics[focus_area.id]
  end

  # "Mon".
  def short_name
    Date::ABBR_DAYNAMES[wday]
  end

  # "Monday".
  def name
    Date::DAYNAMES[wday]
  end

  private
    def topics_short
      errors.add(:topics, "are #{TOPIC_MAX} characters at most each") if topics.values.any? { it.length > TOPIC_MAX }
    end

    # Read from the database, not the plan's loaded focus areas, so one deleted since can't keep a topic.
    def topics_for_own_focus_areas
      errors.add(:topics, "can only be for your own focus areas") if
        topics.any? && (topics.keys - DailyBrief::FocusArea.where(plan_id:).pluck(:id)).any?
    end
end
