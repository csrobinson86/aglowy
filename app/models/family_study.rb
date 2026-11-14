class FamilyStudy < ApplicationRecord
  WEEKS_OF_MONTH = [ 1, 2, 3, 4, 5, -1 ].freeze

  belongs_to :household
  belongs_to :default_conductor, class_name: "User", optional: true
  has_many :sessions, dependent: :destroy

  enum :frequency, %i[ once daily weekly monthly ].index_by(&:itself), default: :once, validate: true

  # A wall-clock time in the household's zone, so never shift it by the process zone (gotcha 14).
  self.skip_time_zone_conversion_for_attributes = %i[ time_of_day ]

  validates :starts_on, :time_of_day, presence: true
  validates :interval, :duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :week_of_month, inclusion: { in: WEEKS_OF_MONTH }, allow_nil: true
  validates :week_of_month, presence: true, if: :monthly?

  # Creates the study and its first session together (scheduling rule 1).
  def schedule(topic: nil)
    transaction do
      save && sessions.create!(recurrence_at: first_session_at, scheduled_at: first_session_at, topic: topic, conductor: default_conductor)
    end
  end

  def recurrence
    Recurrence.new(self)
  end

  def first_session_at
    session_time_on(starts_on)
  end

  # Built in the household's zone, then stored as UTC; never arithmetic on a UTC time (gotcha 14).
  def session_time_on(date)
    ActiveSupport::TimeZone[household.time_zone].local(date.year, date.month, date.day, time_of_day.hour, time_of_day.min)
  end

  # Counted from the month, not Date#cweek: 17 November 2026 is the third Tuesday (scheduling rule 5).
  def week_of_month_for(date)
    (date.day - 1) / 7 + 1
  end

  def last_week_of_month?(date)
    date.next_day(7).month != date.month
  end
end
