require "test_helper"

class MeetingPartsHelperTest < ActionView::TestCase
  test "meeting_part_when gives the day, the meeting and how far away it is" do
    today = Date.new(2026, 11, 17)

    assert_equal "Thursday, December 3 · Midweek meeting · in 16 days", meeting_part_when(Date.new(2026, 12, 3), today)
    assert_equal "Wednesday, November 18 · Midweek meeting · tomorrow", meeting_part_when(today + 1, today)
    assert_equal "Tuesday, November 17 · Midweek meeting · today", meeting_part_when(today, today)
    assert_equal "Monday, November 16 · Midweek meeting · yesterday", meeting_part_when(today - 1, today)
    assert_equal "Thursday, October 8 · Midweek meeting · 40 days ago", meeting_part_when(Date.new(2026, 10, 8), today)
  end
end
