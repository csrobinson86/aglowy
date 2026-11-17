# A done mark for one day of a personal time: state as a record (docs/design/calendar.md, PersonalTime::Completion).
# The day is in the person's zone. A tick and nothing more: never count runs or missed days (Trap 8).
class PersonalTime::Completion < ApplicationRecord
  belongs_to :personal_time

  validates :on, presence: true
  validate :on_a_day_it_falls_on, if: :on

  private
    # Only today or earlier, and only a day the time falls on.
    def on_a_day_it_falls_on
      if on > personal_time.today
        errors.add(:on, "can't be a day that hasn't come yet")
      elsif !personal_time.falls_on?(on)
        errors.add(:on, "isn't a day this time falls on")
      end
    end
end
