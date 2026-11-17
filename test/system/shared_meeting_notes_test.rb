require "application_system_test_case"

class SharedMeetingNotesTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 11, 18, 12)
    meeting_notes(:head_midweek).share_with(households(:home))
  end

  test "another member opens a shared note read-only" do
    sign_in identities(:spouse)
    visit household_meeting_notes_url(household_id: households(:home))

    click_on "Shared in The Head Family"
    assert_selector "ul[aria-label='Show'] a[aria-current='true']", text: "Shared in The Head Family"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Notes"
    assert_text "Hannah Head · Week of November 16–22, 2026"
    assert_accessible
    capture_screens("shared-notes")

    click_on "Life and Ministry"
    assert_selector "h1 .Label", text: "Shared by Hannah Head"
    assert_text "Hannah Head shared this note with The Head Family. You can read it but not change it."
    assert_selector "h3", text: "Talk · [This week's talk title]"
    assert_text "Isaiah 41:10"
    assert_no_selector "h3", text: "Bible Reading"
    assert_no_link "Edit notes"
    assert_no_button "Share with household"
    assert_no_button "Stop sharing"
    assert_no_button "Save notes"
    assert_accessible
    capture_screens("shared-note")
  end
end
