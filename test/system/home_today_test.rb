require "application_system_test_case"

# Today at the top of Home's Mine column (docs/design/calendar.md, Today on Home; frame home-today.png). Tuesday 17
# November 2026 in the home household (UTC), with a weekly family study on Tuesdays at 7:00 PM and Hannah Head's daily
# Bible reading at 6:30 AM.
class HomeTodayTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 11, 17, 15)
    households(:home).family_studies.destroy_all
    households(:home).schedule_family_study(topic: "Proverbs 3", frequency: "weekly", starts_on: Date.new(2026, 11, 17), time_of_day: "19:00", duration_minutes: 45)
    users(:head).update!(time_zone: "UTC")
    users(:head).personal_times.create!(kind: "bible_reading", title: "Daily Bible reading", wdays: (0..6).to_a, time_of_day: "06:30", starts_on: Date.new(2026, 11, 1))
    sign_in identities(:head)
  end

  test "tick today's Bible reading on Home and see it struck through" do
    visit household_root_url(household_id: households(:home))

    within ".today" do
      assert_selector "h3", text: "Today"
      assert_text "Tuesday, November 17"
      assert_selector ".calendar-item--study", text: "Proverbs 3"

      check "Done: Daily Bible reading, Tuesday"
      assert_selector ".calendar-item--my-time.calendar-item--done", text: "Daily Bible reading"
      assert_checked_field "Done: Daily Bible reading, Tuesday"
    end
    assert_equal [ Date.new(2026, 11, 17) ], users(:head).personal_times.sole.completions.pluck(:on)
    assert_accessible
    capture_screens("home-today", scroll_to: ".today")

    visit household_root_url(household_id: households(:home))
    within(".today") { assert_selector ".calendar-item--done", text: "Daily Bible reading" }
  end

  test "open the calendar from the box" do
    visit household_root_url(household_id: households(:home))

    within(".today") { click_on "Open calendar" }

    assert_selector "h1", text: "Calendar"
    assert_current_path household_calendar_path(household_id: households(:home))
  end
end
