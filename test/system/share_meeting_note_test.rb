require "application_system_test_case"

class ShareMeetingNoteTest < ApplicationSystemTestCase
  setup do
    sign_in identities(:head)
  end

  test "open the dialog, share, see the label change, stop sharing" do
    visit household_meeting_note_url(household_id: households(:home), id: meeting_notes(:head_midweek))
    assert_selector "h1 .Label", text: "Private"

    click_on "Share with household"
    within("dialog[open]") do
      assert_selector "h1", text: "Share with The Head Family?"
      assert_text "Everyone in The Head Family will be able to read this note, including children. Nobody else can change it."
      assert_text "The Grandparent Family won't see it."
      assert_text "You can stop sharing at any time, and if you leave The Head Family it stops automatically."
      click_on "Share note"
    end

    assert_text "Shared with The Head Family."
    assert_selector "h1 .Label", text: "Shared with The Head Family"
    capture_screens("share-note-shared")
    click_on "Edit notes"
    assert_text "Members of The Head Family can read this note."

    click_on "Stop sharing"
    assert_text "Stopped sharing with The Head Family."
    assert_selector "h1 .Label", text: "Private"
    assert_selector "button", text: "Share with household"
  end

  test "cancel leaves the note private" do
    visit edit_household_meeting_note_url(household_id: households(:home), id: meeting_notes(:head_midweek))

    click_on "Share with household"
    within("dialog[open]") { click_on "Cancel" }

    assert_no_selector "dialog[open]"
    assert_selector "h1 .Label", text: "Private"
    assert_text "Only you can see this note."
    assert_empty meeting_notes(:head_midweek).sharings
  end

  test "a long household name truncates in the label on a phone" do
    households(:home).update!(name: "The Extraordinarily Long Household Name Family of Springfield")
    meeting_notes(:head_midweek).share_with(households(:home))
    visit household_meeting_note_url(household_id: households(:home), id: meeting_notes(:head_midweek))

    assert_selector "h1 .Label", text: "Shared with The Extraordinarily Long Household Name Family of Springfield"
    capture_screens("share-note-long-name")
  end

  test "the share dialog passes assert_accessible" do
    visit edit_household_meeting_note_url(household_id: households(:home), id: meeting_notes(:head_midweek))

    click_on "Share with household"
    assert_selector "dialog[open]"
    assert_accessible
    capture_screens("share-note")
  end
end
