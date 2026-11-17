# The week or month the calendar shows around a date (docs/design/calendar.md, The page). Weeks start on Monday, like
# meeting weeks; a month is the 6 weeks from the Monday on or before its 1st.
Household::Calendar::Period = Data.define(:view, :date) do
  self::VIEWS = %w[ week month ].freeze

  def month?
    view == "month"
  end

  def days
    (first_day...first_day + (month? ? 42 : 7)).to_a
  end

  def range
    days.first..days.last
  end

  def in_month?(day)
    day.month == date.month
  end

  # "November 16 – 22, 2026", "November 30 – December 6, 2026", or "November 2026".
  def title
    return date.strftime("%B %Y") if month?

    first, last = range.first, range.last
    if first.year != last.year
      "#{first.strftime("%B %-d, %Y")} – #{last.strftime("%B %-d, %Y")}"
    elsif first.month != last.month
      "#{first.strftime("%B %-d")} – #{last.strftime("%B %-d, %Y")}"
    else
      "#{first.strftime("%B %-d")} – #{last.strftime("%-d, %Y")}"
    end
  end

  def previous_date
    month? ? date.beginning_of_month.prev_month : first_day - 7
  end

  def next_date
    month? ? date.beginning_of_month.next_month : first_day + 7
  end

  private
    def first_day
      (month? ? date.beginning_of_month : date).beginning_of_week(:monday)
    end
end
