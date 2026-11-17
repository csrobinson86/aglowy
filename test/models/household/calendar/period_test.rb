require "test_helper"

# The week or month the calendar shows (docs/design/calendar.md, The page).
class Household::Calendar::PeriodTest < ActiveSupport::TestCase
  test "a week runs Monday to Sunday, and steps a week at a time" do
    period = Household::Calendar::Period.new(view: "week", date: Date.new(2026, 11, 19))

    assert_equal Date.new(2026, 11, 16)..Date.new(2026, 11, 22), period.range
    assert_equal "November 16 – 22, 2026", period.title
    assert_equal [ Date.new(2026, 11, 9), Date.new(2026, 11, 23) ], [ period.previous_date, period.next_date ]
  end

  test "a week's title names both months, or both years, when it crosses one" do
    assert_equal "November 30 – December 6, 2026", Household::Calendar::Period.new(view: "week", date: Date.new(2026, 12, 1)).title
    assert_equal "December 28, 2026 – January 3, 2027", Household::Calendar::Period.new(view: "week", date: Date.new(2026, 12, 31)).title
  end

  test "a month is 6 weeks from the Monday on or before the 1st, and steps a month at a time" do
    period = Household::Calendar::Period.new(view: "month", date: Date.new(2026, 11, 19))

    assert_equal Date.new(2026, 10, 26)..Date.new(2026, 12, 6), period.range
    assert_equal 42, period.days.size
    assert_equal "November 2026", period.title
    assert_equal [ Date.new(2026, 10, 1), Date.new(2026, 12, 1) ], [ period.previous_date, period.next_date ]
    assert period.in_month?(Date.new(2026, 11, 30))
    assert_not period.in_month?(Date.new(2026, 12, 1))
  end
end
