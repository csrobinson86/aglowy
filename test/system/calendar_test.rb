require "application_system_test_case"

# The household's calendar of meetings and family studies, by week and month (docs/design/calendar.md; frames
# calendar-week.png, calendar-month.png and calendar-dark.png).
class CalendarTest < ApplicationSystemTestCase
  # Tuesday 17 November 2026, with the midweek meeting on Thursday at 7:00 PM, the weekend meeting on Sunday at 10:00 AM
  # and a weekly family study on Tuesdays at 7:00 PM.
  setup do
    travel_to Time.utc(2026, 11, 17, 15)
    households(:home).change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    # The fixture parts are dated from the real today, so as the days pass one would land in this week. Tests add their own.
    MeetingPart.delete_all
    households(:home).family_studies.destroy_all
    households(:home).schedule_family_study(topic: "Proverbs 3", frequency: "weekly", starts_on: Date.new(2026, 11, 17), time_of_day: "19:00", duration_minutes: 45)
    sign_in identities(:head)
  end

  test "open Calendar from the sidebar; go to the next week and back; switch to Month" do
    visit household_root_url(household_id: households(:home))

    within("nav[aria-label='Main']") { click_on "Calendar" }

    assert_selector "h1", text: "Calendar"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Calendar"
    assert_selector "h2", text: "November 16 – 22, 2026"
    assert_selector "section[aria-current=date] h3", text: "Tue 17"

    find("a[aria-label='Next week']").click
    assert_selector "h2", text: "November 23 – 29, 2026"
    assert_no_selector "section[aria-current=date]"

    find("a[aria-label='Previous week']").click
    assert_selector "h2", text: "November 16 – 22, 2026"

    click_on "Month"
    assert_selector "h2", text: "November 2026"
    assert_selector ".calendar-month__day", count: 42
    assert_selector ".calendar-item--study", text: "7:00 PM Family study"
    assert_accessible
    capture_screens("calendar-month")

    click_on "Today"
    assert_selector "h2", text: "November 2026"
    click_on "Week"
    assert_selector "h2", text: "November 16 – 22, 2026"
  end

  test "untick Meetings" do
    visit household_calendar_url(household_id: households(:home))
    assert_selector ".calendar-item--meeting", count: 2

    uncheck "Meetings"

    assert_no_selector ".calendar-item--meeting"
    assert_no_checked_field "Meetings"
    assert_checked_field "Family studies"
    assert_selector ".calendar-item--study", text: "Proverbs 3"

    find("a[aria-label='Next week']").click
    assert_selector "h2", text: "November 23 – 29, 2026"
    assert_no_selector ".calendar-item--meeting"
  end

  test "open a meeting's note from it" do
    visit household_calendar_url(household_id: households(:home))

    find("button.calendar-item--meeting", text: "Midweek meeting").click

    assert_current_path household_meeting_note_path(household_id: households(:home), id: meeting_notes(:head_midweek))
  end

  test "open the part from the calendar" do
    part = users(:head).meeting_parts.create!(kind: "starting_a_conversation", meeting_on: Date.new(2026, 11, 19), minutes: 3, topic: "Hope for the future")
    users(:head).meeting_parts.create!(kind: "talk", meeting_on: Date.new(2026, 11, 21), minutes: 5, topic: "Why we can trust the Bible")
    visit household_calendar_url(household_id: households(:home))

    assert_selector "a.calendar-item--meeting-part", text: /7:00 PM\s+Your part: Starting a Conversation\s+3 min/
    assert_selector ".calendar-band a.calendar-item--meeting-part", text: /Your part: Talk\s+5 min/
    assert_accessible
    capture_screens("calendar-week-part")

    click_on "Your part: Starting a Conversation"

    assert_current_path household_meeting_part_path(household_id: households(:home), id: part)
    assert_selector "h1", text: "Starting a Conversation"
  end

  test "the calendar is accessible in light and dark" do
    visit household_calendar_url(household_id: households(:home))
    assert_selector ".calendar-item--study", text: "Proverbs 3"
    assert_accessible
    capture_screens("calendar-week")

    users(:head).update!(appearance: "dark")
    visit household_calendar_url(household_id: households(:home))
    assert_selector "body[data-color-mode=dark]"
    assert_selector ".calendar-item--meeting", text: "Weekend meeting"
    assert_accessible
  end
end
