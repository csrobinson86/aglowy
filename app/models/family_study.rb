class FamilyStudy < ApplicationRecord
  WEEKS_OF_MONTH = [ 1, 2, 3, 4, 5, -1 ].freeze

  belongs_to :household
  belongs_to :default_conductor, class_name: "User", optional: true
  has_many :sessions, dependent: :destroy

  enum :frequency, %i[ once daily weekly monthly ].index_by(&:itself), default: :once, validate: true

  scope :repeating, -> { where.not(frequency: :once) }
  scope :ongoing, -> { where(ends_on: nil).or(where(ends_on: Date.current.next_day..)) }
  scope :preloaded, -> { includes(:household) }

  # A wall-clock time in the household's zone, so never shift it by the process zone (gotcha 14).
  self.skip_time_zone_conversion_for_attributes = %i[ time_of_day ]

  validates :starts_on, :time_of_day, presence: true
  validates :interval, :duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :week_of_month, inclusion: { in: WEEKS_OF_MONTH }, allow_nil: true
  validates :week_of_month, presence: true, if: :monthly?

  # Sessions exist through the end of the service year (31 August), and never less than the minimum ahead (scheduling rule 4).
  def self.horizon(today = Date.current)
    end_of_service_year = Date.new(today.year, 8, 31)
    end_of_service_year = end_of_service_year.next_year if end_of_service_year < today

    [ end_of_service_year, today + Rails.configuration.x.family_studies.minimum_horizon ].max
  end

  # Creates the study and its first session together, then a repeating study's later ones (scheduling rule 1).
  def schedule(topic: nil)
    transaction do
      next false unless save

      sessions.create!(recurrence_at: first_session_at, scheduled_at: first_session_at, topic: topic, conductor: default_conductor)
      extend_sessions unless once?
      true
    end
  end

  # Safe to run twice: insert_all skips slots that already have a session, even a moved or cancelled one (gotchas 15 and 21).
  def extend_sessions(through: FamilyStudy.horizon)
    sessions.insert_all(new_session_rows(through: through), unique_by: %i[ family_study_id recurrence_at ])
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

  private
    # insert_all skips callbacks, so the UUIDv7 id is set here; timestamps too, so they follow the app's clock.
    def new_session_rows(through:)
      times = recurrence.dates(from: Date.current, through: through).map { session_time_on(it) }
      created_at = Time.current

      (times - sessions.where(recurrence_at: times).pluck(:recurrence_at)).map do |time|
        { id: SecureRandom.uuid_v7, family_study_id: id, recurrence_at: time, scheduled_at: time,
          conductor_id: default_conductor_id, created_at: created_at, updated_at: created_at }
      end
    end
end
