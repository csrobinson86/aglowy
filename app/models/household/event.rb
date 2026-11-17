# A household's own event: a circuit assembly, the circuit overseer's visit, Saturday field service, Kingdom Hall
# cleaning (docs/design/calendar.md, Household::Event). Everyone in the household sees it; heads and adults add it.
# Occurrences are worked out for the range asked for, never stored (Trap 6).
class Household::Event < ApplicationRecord
  KINDS = { "circuit_assembly" => "Circuit assembly", "regional_convention" => "Regional convention",
            "co_visit" => "Circuit overseer's visit", "memorial" => "Memorial", "field_service" => "Field service", "other" => "Other" }.freeze
  # The kinds the dialog checks All day for (The household event dialog).
  ALL_DAY_KINDS = %w[ circuit_assembly regional_convention co_visit ].freeze
  MAX_DAYS = 14

  include Household::Event::Schedulable

  belongs_to :household
  belongs_to :created_by, class_name: "User"

  enum :kind, KINDS.keys.index_by(&:itself), validate: true
  enum :frequency, %w[ once weekly monthly ].index_by(&:itself), default: :once, validate: true

  encrypts :note

  scope :preloaded, -> { includes(:created_by) }

  # A wall-clock time in the household's zone, so never shift it by the process zone (family-studies gotcha 14).
  self.skip_time_zone_conversion_for_attributes = %i[ time_of_day ]

  validates :title, presence: true, length: { maximum: 80 }
  validates :starts_on, presence: true
  validates :days, numericality: { only_integer: true, in: 1..MAX_DAYS }
  validates :days, comparison: { equal_to: 1, message: "must be 1 unless it's all day and doesn't repeat" }, unless: -> { all_day? && once? }
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 720 }, if: :time_of_day
  validates :duration_minutes, absence: true, unless: :time_of_day
  validates :interval, numericality: { only_integer: true, greater_than: 0 }
  validates :week_of_month, inclusion: { in: FamilyStudy::WEEKS_OF_MONTH }, allow_nil: true
  validates :week_of_month, presence: true, if: :monthly?
  validates :location, length: { maximum: 120 }
  validates :note, length: { maximum: 500 }

  def self.default_title(kind)
    KINDS.fetch(kind, "")
  end

  def all_day?
    time_of_day.nil?
  end

  def last_day
    starts_on + days - 1
  end

  def recurrence
    Recurrence.new(frequency:, interval:, starts_on:, ends_on: repeats_until, week_of_month:)
  end

  # Each occurrence that touches the dates in the range, as its start...end in the household's zone. A several-day
  # event is one occurrence from the midnight it starts to the midnight after its last day, so one that began before
  # the range still shows. Every time is built with zone.local from a local date, never by adding days (Trap 1).
  def occurrences_between(range)
    zone = ActiveSupport::TimeZone[household.time_zone]

    recurrence.dates(from: range.first - (days - 1), through: range.last).map do |date|
      if all_day?
        zone.local(date.year, date.month, date.day)...(date + days).then { zone.local(it.year, it.month, it.day) }
      else
        starts_at = zone.local(date.year, date.month, date.day, time_of_day.hour, time_of_day.min)
        starts_at...starts_at + duration_minutes.minutes
      end
    end
  end
end
