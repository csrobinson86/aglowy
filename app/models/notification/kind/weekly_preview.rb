# "Your week in Rivera household": Sunday evening's look at the household's coming week, for every member. The second
# line is worked out from the calendar when it's shown, never stored, and it opens that week on the calendar.
class Notification::Kind::WeeklyPreview < Notification::Kind
  def icon = :calendar
  def color = :purple
  def email = :right_away
  def label = "Weekly preview"
  def description = "Sunday evening: each household's week ahead."

  def title
    "Your week in #{subject.name}"
  end

  # "Your week in Rivera household: November 23 – 29", or "November 30 – December 6" across two months.
  def email_subject
    last = week_of + 6
    "#{title}: #{week_of.strftime("%B %-d")} – #{last.strftime(week_of.month == last.month ? "%-d" : "%B %-d")}"
  end

  def body
    Household::WeeklyPreview.new(subject, week_of:).summary
  end

  def target_path
    household_calendar_path(household_id:, view: "week", date: week_of.iso8601)
  end

  private
    def week_of
      Date.parse(notification.data.fetch("week_of"))
    end
end
