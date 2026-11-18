require "test_helper"

# Today at the top of Home's Mine column (docs/design/calendar.md, Today on Home; frame home-today.png). Tuesday 17
# November 2026 in the home household (UTC), seen by Hannah Head.
class TodayComponentTest < ViewComponent::TestCase
  setup do
    travel_to Time.utc(2026, 11, 17, 15)
    Current.identity = identities(:head)
    # The fixture parts are dated from the real today, so as the days pass one would land in this week. Tests add their own.
    MeetingPart.delete_all
    Current.membership = memberships(:head_in_home)
    households(:home).events.destroy_all
    households(:home).family_studies.destroy_all
    users(:head).update!(time_zone: "UTC")
  end

  test "a meeting, a study, an event and two of my times in order" do
    households(:home).change_meeting_times(midweek_wday: 2, midweek_time: "19:30", weekend_wday: 0, weekend_time: "10:00")
    households(:home).schedule_family_study(topic: "Proverbs 3", frequency: "weekly", starts_on: Date.new(2026, 11, 17), time_of_day: "17:00", duration_minutes: 45)
    households(:home).events.create!(kind: "field_service", title: "Field service", starts_on: Date.new(2026, 11, 17), time_of_day: "09:30",
                                     duration_minutes: 90, location: "Kingdom Hall", created_by: users(:spouse))
    my_time("Daily Bible reading", "06:30")
    my_time("Personal study", "12:00", kind: "personal_study")

    render_today

    assert_selector ".Box-header h3", text: "Today"
    assert_selector ".Box-header", text: "Tuesday, November 17"
    assert_equal [ "Daily Bible reading", "Field service", "Personal study", "Family study", "Midweek meeting" ],
                 page.all(".today__item .calendar-item__title").map { it.text.strip }
    assert_equal [ "6:30 AM", "9:30 AM", "12:00 PM", "5:00 PM", "7:30 PM" ], page.all(".today__item .calendar-item__time").map { it.text.strip }
    assert_selector ".today__item .calendar-item--my-time", count: 2
    assert_selector ".today__item .calendar-item--field-service", text: "Kingdom Hall"
    assert_selector ".today__item a.calendar-item--study", text: "Proverbs 3"
    assert_selector ".today__item button.calendar-item--meeting", text: "Midweek meeting"
    assert_unchecked_field "Done: Daily Bible reading, Tuesday"
    assert_unchecked_field "Done: Personal study, Tuesday"
    assert_link "Open calendar", href: "/#{households(:home).id}/calendar"
    assert_no_text "Nothing on your calendar today."
  end

  test "a done time struck through" do
    my_time("Daily Bible reading", "06:30").complete(on: Date.new(2026, 11, 17))

    render_today

    assert_selector ".today__item .calendar-item--my-time.calendar-item--done", text: "Daily Bible reading"
    assert_checked_field "Done: Daily Bible reading, Tuesday"
  end

  test "another member's shared time left out" do
    users(:spouse).update!(time_zone: "UTC")
    users(:spouse).personal_times.create!(kind: "bible_reading", title: "Sam's reading", wdays: [ 2 ], time_of_day: "07:00", starts_on: Date.new(2026, 11, 1))
    memberships(:spouse_in_home).share_times
    my_time("Daily Bible reading", "06:30")

    render_today

    assert_selector ".today__item", count: 1
    assert_text "Daily Bible reading"
    assert_no_text "Sam's reading"
    assert_no_selector ".calendar-item--shared"
  end

  test "the empty state" do
    render_today

    assert_selector ".Box-header h3", text: "Today"
    assert_text "Nothing on your calendar today."
    assert_no_selector ".today__item"
    assert_link "Open calendar"
  end

  test "a child's event isn't a link, and today's meeting opens Today's meeting" do
    households(:home).change_meeting_times(midweek_wday: 2, midweek_time: "19:30", weekend_wday: 0, weekend_time: "10:00")
    households(:home).events.create!(kind: "field_service", title: "Field service", starts_on: Date.new(2026, 11, 17), time_of_day: "09:30",
                                     duration_minutes: 90, created_by: users(:spouse))

    render_today(meeting_helper: true, manage_events: false)

    assert_selector ".today__item div.calendar-item--field-service", text: "Field service"
    assert_no_selector ".today__item a.calendar-item--field-service"
    assert_selector ".today__item a.calendar-item--meeting[href='/#{households(:home).id}/todays_meeting']", text: "Midweek meeting"
  end

  private
    def render_today(meeting_helper: false, manage_events: true)
      with_request_url("/#{households(:home).id}/calendar") do
        render_inline(TodayComponent.new(household: households(:home), viewer: users(:head), meeting_helper:, manage_events:))
      end
    end

    def my_time(title, at, kind: "bible_reading")
      users(:head).personal_times.create!(kind:, title:, wdays: [ 2 ], time_of_day: at, starts_on: Date.new(2026, 11, 1))
    end
end
