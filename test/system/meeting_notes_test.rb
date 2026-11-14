require "application_system_test_case"

class MeetingNotesTest < ApplicationSystemTestCase
  test "start this week's Life and Ministry note from the list and land on it" do
    travel_to Time.utc(2026, 11, 25, 12) # a week with no notes yet
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))
    within("nav[aria-label='Main']") { click_on "Meeting notes" }

    assert_selector "h1", text: "Meeting notes"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Meeting notes"
    assert_selector "button", text: "Start notes", count: 2
    assert_accessible
    capture_screens("meeting-notes-not-started")
    within(".Box", text: /\ALife and Ministry/) { click_on "Start notes" }

    assert_selector "h1", text: "Life and Ministry"
    assert_text "Week of November 23–29, 2026"
    assert_text "Nothing written yet."
    assert_equal users(:head).meeting_notes.find_by!(kind: "midweek", week_of: Date.new(2026, 11, 23)).id, current_path.split("/").last
  end

  test "empty parts aren't shown" do
    sign_in identities(:head)

    visit household_meeting_note_url(household_id: households(:home), id: meeting_notes(:head_midweek))

    assert_selector "h3", text: "Talk · [This week's talk title]"
    assert_text "Jehovah promises to strengthen us, not just to watch from a distance."
    assert_selector "h3", text: "Congregation Bible Study"
    assert_no_text "Bible Reading"
    assert_no_text "Apply Yourself to the Field Ministry"
  end

  test "the list and the note pass assert_accessible" do
    travel_to Time.utc(2026, 11, 18, 12)
    users(:head).start_meeting_note(kind: "weekend", week_of: Date.new(2026, 11, 9))
    users(:head).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    sign_in identities(:head)

    visit household_meeting_notes_url(household_id: households(:home))
    assert_selector ".Box-row", count: 2
    assert_accessible
    capture_screens("meeting-notes")

    within(".Box", text: /\ALife and Ministry/) { click_on "Open notes" }
    assert_selector "h1", text: "Life and Ministry"
    assert_accessible
    capture_screens("meeting-note")
  end
end
