require "test_helper"

# The week of Monday 16 November 2026 in Chicago: a weekly family study on Tuesdays at 7:00 PM, the midweek meeting on
# Thursday at 7:00 PM and the weekend meeting on Sunday at 10:00 AM (docs/design/calendar.md, How a calendar is put together).
class Household::CalendarTest < ActiveSupport::TestCase
  CHICAGO = ActiveSupport::TimeZone["Central Time (US & Canada)"]
  WEEK = Date.new(2026, 11, 16)..Date.new(2026, 11, 22)

  setup do
    travel_to Time.utc(2026, 11, 16, 12)
    @household = households(:parents)
    @household.update!(time_zone: CHICAGO.name)
    @household.change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    @study = @household.schedule_family_study(topic: "Proverbs 3", frequency: "weekly", starts_on: Date.new(2026, 11, 17), time_of_day: "19:00")
  end

  test "meetings and sessions in the range, in order" do
    items = calendar(WEEK).items

    assert_equal [ [ "study", "Family study", "Proverbs 3", CHICAGO.local(2026, 11, 17, 19) ],
                   [ "meeting", "Midweek meeting", nil, CHICAGO.local(2026, 11, 19, 19) ],
                   [ "meeting", "Weekend meeting", nil, CHICAGO.local(2026, 11, 22, 10) ] ],
                 items.map { [ it.kind, it.title, it.subtitle, it.starts_at ] }
    assert_equal @study.first_session, items.first.source
    assert_equal CHICAGO.local(2026, 11, 17, 20), items.first.ends_at
  end

  test "a cancelled session is left out" do
    @study.first_session.cancel

    assert_equal [ "Midweek meeting", "Weekend meeting" ], calendar(WEEK).items.map(&:title)
  end

  test "a weekly study shows in a week past the stored-session horizon, as \"Topic not chosen yet\", with nothing stored" do
    assert_equal Date.new(2027, 8, 31), FamilyStudy.horizon
    past_horizon = Date.new(2027, 9, 6)..Date.new(2027, 9, 12)

    items = assert_no_difference -> { FamilyStudy::Session.count } do
      calendar(past_horizon).items
    end

    study = items.find { it.kind == "study" }
    assert_equal [ "Family study", "Topic not chosen yet", CHICAGO.local(2027, 9, 7, 19) ], [ study.title, study.subtitle, study.starts_at ]
    assert study.source.new_record?
  end

  test "items_on a day" do
    calendar = calendar(WEEK)

    assert_equal [ "Midweek meeting" ], calendar.items_on(Date.new(2026, 11, 19)).map(&:title)
    assert_empty calendar.items_on(Date.new(2026, 11, 18))
  end

  test "hiding meetings leaves only the studies" do
    assert_equal [ "study" ], calendar(WEEK, hide: %w[ meetings ]).items.map(&:kind)
    assert_equal [ "meeting", "meeting" ], calendar(WEEK, hide: %w[ family_studies ]).items.map(&:kind)
  end

  test "nothing planned: no meeting times and no studies" do
    assert_not calendar(WEEK).nothing_planned?

    @household.family_studies.destroy_all
    @household.update_columns(midweek_meeting_wday: nil, midweek_meeting_time: nil, weekend_meeting_wday: nil, weekend_meeting_time: nil)
    assert calendar(WEEK).nothing_planned?
  end

  private
    def calendar(range, hide: [])
      Household::Calendar.new(@household, viewer: users(:grandparent), range:, hide:)
    end
end
