# The Schedule a study form: friendly Date, Starts, Ends and Repeat values, saved as a
# FamilyStudy with starts_on, time_of_day and duration_minutes (docs/design/family-studies.md).
class FamilyStudy::Scheduling
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_reader :household, :study

  attribute :topic, :string
  attribute :starts_on, :date
  attribute :starts_at, :time
  attribute :ends_at, :time
  attribute :repeat, :string, default: "once"

  validates :starts_on, :starts_at, :ends_at, presence: true
  validates :repeat, inclusion: { in: ->(scheduling) { scheduling.repeat_choices.map(&:last) } }
  validate :starts_on_not_in_the_past, :ends_after_starts

  def initialize(household:, **attributes)
    @household = household
    # Today unless the form sent a date, even a blank one.
    super(starts_on: today, **attributes)
  end

  # Scheduling rule 5: what the date offers, as [label, value] for the Repeat select.
  def repeat_choices
    [ [ "Does not repeat", "once" ], [ "Daily", "daily" ] ].tap do |choices|
      next unless starts_on

      choices << [ "Weekly on #{weekday}", "weekly" ]
      choices << [ "Monthly on the #{FamilyStudy::ORDINALS[week_of_month - 1]} #{weekday}", "monthly" ]
      choices << [ "Monthly on the last #{weekday}", "monthly_last" ] if calendar.last_week_of_month?(starts_on)
    end
  end

  # The study, its first session with the topic, then the later sessions (scheduling rule 1).
  def save
    return false unless valid?

    @study = household.schedule_family_study(topic: topic.presence, **study_attributes)
    study.persisted?
  end

  private
    def study_attributes
      { starts_on: starts_on, time_of_day: starts_at.strftime("%H:%M"), duration_minutes: duration_minutes, **repetition }
    end

    def repetition
      case repeat
      when "monthly"      then { frequency: "monthly", week_of_month: week_of_month }
      when "monthly_last" then { frequency: "monthly", week_of_month: -1 }
      else { frequency: repeat }
      end
    end

    def duration_minutes
      ((ends_at - starts_at) / 60).floor
    end

    def weekday
      starts_on.strftime("%A")
    end

    def week_of_month
      calendar.week_of_month_for(starts_on)
    end

    # The week-of-month rules live on FamilyStudy, so the form and the schedule can't disagree.
    def calendar
      @calendar ||= FamilyStudy.new
    end

    def today
      Time.current.in_time_zone(household.time_zone).to_date
    end

    def starts_on_not_in_the_past
      errors.add(:starts_on, "can't be in the past") if starts_on && starts_on < today
    end

    # Both times are on the same day, so an end after midnight looks like one before the start.
    # Judged in whole minutes, the unit the study stores.
    def ends_after_starts
      if starts_at && ends_at && duration_minutes < 1
        errors.add(:ends_at, "must be after Starts. Studies that end after midnight aren't supported.")
      end
    end
end
