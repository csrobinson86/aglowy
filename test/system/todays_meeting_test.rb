require "application_system_test_case"

class TodaysMeetingTest < ApplicationSystemTestCase
  test "an adult with times set opens Today's meeting from the sidebar, taps Start my notes and lands on the note's edit page" do
    travel_to Time.utc(2026, 11, 19, 18) # Thursday, an hour before the midweek meeting
    households(:home).change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    sign_in identities(:spouse)
    visit household_root_url(household_id: households(:home))

    within("nav[aria-label='Main']") { click_on "Today's meeting" }

    assert_selector "h1", text: "Today's meeting"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Today's meeting"
    assert_text "Midweek meeting · Thursday 7:00 PM"
    assert_accessible
    capture_screens("todays-meeting")
    click_on "Start my notes"

    assert_selector "h1", text: "Life and Ministry"
    note = users(:spouse).meeting_notes.find_by!(kind: "midweek", week_of: Date.new(2026, 11, 16))
    assert_current_path edit_household_meeting_note_path(household_id: households(:home), id: note)
  end

  test "before any times are set, a head picks which meeting it is" do
    travel_to Time.utc(2026, 11, 25, 12) # a week with no notes yet
    sign_in identities(:head)
    visit household_todays_meeting_url(household_id: households(:home))

    assert_selector "h2", text: "Which meeting is it?"
    assert_link "Set your meeting times"
    assert_accessible
    capture_screens("todays-meeting-pick")
    click_on "Weekend meeting"

    assert_selector "h1", text: "Weekend meeting"
    note = users(:head).meeting_notes.find_by!(kind: "weekend", week_of: Date.new(2026, 11, 23))
    assert_current_path edit_household_meeting_note_path(household_id: households(:home), id: note)
  end
end
