# One day of a personal time (docs/design/calendar.md, PersonalTime): on is the date in the person's zone, starts_at the
# instant it begins, and done whether it's marked done that day.
PersonalTime::Occurrence = Data.define(:personal_time, :on, :starts_at, :done) do
  delegate :title, :kind, to: :personal_time

  def ends_at
    starts_at + personal_time.duration_minutes.minutes
  end

  # What the calendar's subtitle links to: a study or a note, or for meeting prep that week's next meeting (as a
  # Household::Meeting), or nil.
  def opens(household)
    personal_time.meeting_prep? ? personal_time.meeting_note_for(on, household:) : personal_time.opens
  end

  def opens_title(household)
    case target = opens(household)
    when Household::Meeting then "#{target.kind == "midweek" ? "Life and Ministry" : "Weekend meeting"} notes"
    when nil then nil
    else target.title
    end
  end

  def done?
    done
  end

  # No done box on a day that hasn't come yet where the person lives.
  def future?
    on > personal_time.today
  end
end
