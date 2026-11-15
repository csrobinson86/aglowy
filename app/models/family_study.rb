class FamilyStudy < ApplicationRecord
  WEEKS_OF_MONTH = [ 1, 2, 3, 4, 5, -1 ].freeze
  ORDINALS = %w[ first second third fourth fifth ].freeze

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

  # Creates the study and its first session (with any links and files) together, then a repeating study's later ones (scheduling rule 1).
  def schedule(topic: nil, notes: nil, links: [], files: [])
    transaction do
      next false unless save

      # Assigning nil notes would still store an empty rich text, so notes go in only when given.
      first_session = sessions.create!(recurrence_at: first_session_at, scheduled_at: first_session_at, topic: topic, conductor: default_conductor, **{ notes: notes }.compact)
      links.each { first_session.resources.create!(url: it) }
      files.each { first_session.resources.create!(kind: :file, file: it) }
      extend_sessions unless once?
      true
    end
  end

  # Safe to run twice: insert_all skips slots that already have a session, even a moved or cancelled one (gotchas 15 and 21).
  # Behind the household's lock, which re-reads its zone, so a time zone change can't land between building the slots
  # and inserting them (Household#update_settings).
  def extend_sessions(through: FamilyStudy.horizon)
    household.with_lock do
      sessions.insert_all(new_session_rows(through: through), unique_by: %i[ family_study_id recurrence_at ])
    end
  end

  # How the session page says it repeats: "Once", "Weekly on Tuesday", "Monthly on the last Tuesday".
  def repeat_description
    case frequency
    when "once"    then "Once"
    when "daily"   then every("day")
    when "weekly"  then "#{every("week")} on #{weekday}"
    when "monthly" then "#{every("month")} on the #{week_of_month == -1 ? "last" : ORDINALS[week_of_month - 1]} #{weekday}"
    end
  end

  # How Home's label says it repeats: a weekly study meets "on Tuesdays"; the rest read as repeat_description.
  def repeat_label
    weekly? ? "#{every("week")} on #{weekday.pluralize}" : repeat_description
  end

  def recurrence
    Recurrence.new(self)
  end

  def first_session_at
    session_time_on(starts_on)
  end

  # Built in the household's zone, then stored as UTC; never arithmetic on a UTC time (gotcha 14). A zone change
  # passes the new zone, so a moved slot is built exactly as the generator will build it.
  def session_time_on(date, zone: ActiveSupport::TimeZone[household.time_zone])
    zone.local(date.year, date.month, date.day, time_of_day.hour, time_of_day.min)
  end

  # Counted from the month, not Date#cweek: 17 November 2026 is the third Tuesday (scheduling rule 5).
  def week_of_month_for(date)
    (date.day - 1) / 7 + 1
  end

  def last_week_of_month?(date)
    date.next_day(7).month != date.month
  end

  private
    # "Weekly", or "Every 2 weeks" when the interval is more than one.
    def every(unit)
      interval == 1 ? frequency.capitalize : "Every #{interval} #{unit.pluralize}"
    end

    def weekday
      starts_on.strftime("%A")
    end

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
