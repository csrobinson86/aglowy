require "application_system_test_case"

# Sharing my times with a household (docs/design/calendar.md, Settings → Calendar and Membership::TimeSharing; frames
# settings-calendar.png, calendar-week.png and calendar-child.png). Tuesday 17 November 2026 in the home household
# (UTC). Eli, a child with a login, plays Daniel from the frames, and Hannah Head plays Maria.
class CalendarSharingTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 11, 17, 15)
    users(:eli).update!(time_zone: "UTC")
    users(:eli).personal_times.create!(kind: "personal_study", title: "Personal study", wdays: [ 3 ], time_of_day: "21:00", starts_on: Date.new(2026, 11, 1))
  end

  test "a child shares in Settings → Calendar; a head sees \"Eli's time\" on the calendar, with no done box and no link" do
    sign_in identities(:eli)
    visit household_calendar_url(household_id: households(:home))
    click_on "Share them"

    assert_selector "h2", text: "Calendar"
    assert_selector "nav[aria-label='Settings'] a[aria-current=page]", text: "Calendar"
    assert_text "Who sees your times, and your phone calendar link."
    assert_unchecked_field "The Head Family"
    assert_accessible
    capture_screens("settings-calendar")

    check "The Head Family"
    click_on "Save"
    assert_text "Sharing saved."
    assert_checked_field "The Head Family"

    visit household_calendar_url(household_id: households(:home))
    assert_text "Your times are shared with The Head Family."
    assert_selector ".calendar-item--my-time", text: "Personal study"
    assert_no_selector ".calendar-item--shared"

    sign_out :identity
    sign_in identities(:head)
    visit household_calendar_url(household_id: households(:home))

    assert_checked_field "Eli's times"
    within ".calendar-item--shared" do
      assert_text "9:00 PM"
      assert_text "Personal study"
      assert_text "Eli's time"
      assert_no_selector "input[type=checkbox]"
      assert_no_selector "a, button"
    end
    assert_no_selector "a.calendar-item--shared, button.calendar-item--shared"
    assert_text "Only you see your times."
    assert_accessible
    capture_screens("calendar-shared")

    uncheck "Eli's times"
    assert_no_selector ".calendar-item--shared"
  end
end
