# The household event dialog's fields (docs/design/calendar.md, The household event dialog): All day, then Starts and
# Ends dates, or a Date with Starts and Ends times; and Repeats, offered from the date by the family studies rule
# (scheduling rule 5, without Daily). schedule turns them into the event's columns and saves. An event read back
# answers each field from its columns, so the edit dialog shows what was saved; a field that was sent, even blank or
# unreadable, answers what was sent, so it's refused rather than replaced by what was saved.
module Household::Event::Schedulable
  extend ActiveSupport::Concern

  included do
    attribute :all_day, :boolean
    attribute :ends_on, :date
    attribute :starts_at, :time
    attribute :ends_at, :time
    attribute :repeat, :string

    validate :times_in_order
    validate :repeat_offered, if: -> { read_attribute(:repeat).present? && days == 1 }
  end

  def schedule(attributes)
    assign_attributes(attributes)
    schedule_from_fields
    save
  end

  def all_day
    super.nil? ? time_of_day.nil? : super
  end

  def ends_on
    ends_on_came_from_user? ? super : (last_day if starts_on)
  end

  def starts_at
    starts_at_came_from_user? ? super : time_of_day
  end

  def ends_at
    ends_at_came_from_user? ? super : (time_of_day + duration_minutes.minutes if time_of_day && duration_minutes)
  end

  def repeat
    super || (monthly? && week_of_month == -1 ? "monthly_last" : frequency)
  end

  # The dialog hides Repeats for an all-day event that ends on a later day.
  def several_days?
    all_day && starts_on.present? && ends_on.present? && ends_on > starts_on
  end

  # What the date offers, as [label, value] for the Repeats select.
  def repeat_choices
    [ [ "Doesn't repeat", "once" ] ].tap do |choices|
      next unless starts_on

      weekday = starts_on.strftime("%A")
      choices << [ "Weekly on #{weekday}", "weekly" ]
      choices << [ "Monthly on the #{FamilyStudy::ORDINALS[rules.week_of_month_for(starts_on) - 1]} #{weekday}", "monthly" ]
      choices << [ "Monthly on the last #{weekday}", "monthly_last" ] if rules.last_week_of_month?(starts_on)
    end
  end

  private
    # A several-day event never repeats: the dialog hides Repeats then, and leaves whatever it last held.
    def schedule_from_fields
      if all_day
        self.time_of_day = self.duration_minutes = nil
        self.days = (ends_on - starts_on).to_i + 1 if starts_on && ends_on && ends_on >= starts_on
      else
        self.days = 1
        self.time_of_day = starts_at&.strftime("%H:%M")
        self.duration_minutes = timed_minutes
      end

      repeat_as = days > 1 ? "once" : repeat
      self.frequency = repeat_as == "monthly_last" ? "monthly" : repeat_as
      self.week_of_month = case repeat_as
      when "monthly"      then rules.week_of_month_for(starts_on) if starts_on
      when "monthly_last" then -1
      end
    end

    def timed_minutes
      ((ends_at - starts_at) / 60).floor if starts_at && ends_at
    end

    # A timed event needs both times. They're on the same day, so an end after midnight looks like one before the start.
    def times_in_order
      if all_day
        return unless starts_on
        return errors.add(:ends_on, :blank) unless ends_on

        errors.add(:ends_on, "can't be before Starts") if ends_on < starts_on
        errors.add(:ends_on, "can be at most #{Household::Event::MAX_DAYS - 1} days after Starts") if ends_on - starts_on >= Household::Event::MAX_DAYS
      elsif starts_at.nil? || ends_at.nil?
        errors.add(starts_at ? :ends_at : :starts_at, :blank)
      elsif timed_minutes < 1
        errors.add(:ends_at, "must be after Starts")
      end
    end

    # Sent before the Repeats frame caught up with a new date, or crafted: shown by Repeats, not saved on another day.
    def repeat_offered
      errors.add(:repeat, "isn't offered for that date") unless repeat.in?(repeat_choices.map(&:last))
    end

    # The week-of-month rules live on FamilyStudy, so a study and an event can't disagree (as FamilyStudy::Scheduling).
    def rules
      @rules ||= FamilyStudy.new
    end
end
