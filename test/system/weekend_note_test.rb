require "application_system_test_case"

class WeekendNoteTest < ApplicationSystemTestCase
  # Moves the caret to the end of the editor's text: Cmd+Down on a Mac, Ctrl+End on Linux CI.
  END_OF_TEXT = RUBY_PLATFORM.include?("darwin") ? [ :command, :down ] : [ :control, :end ]

  test "start this week's weekend note, write talk notes, save and read them" do
    travel_to Time.utc(2026, 11, 25, 12) # a week with no notes yet
    sign_in identities(:head)
    visit household_meeting_notes_url(household_id: households(:home))
    within(".Box", text: /\AWeekend meeting.*Not started/m) { click_on "Start notes" }

    assert_selector "h1", text: "Weekend meeting"
    assert_text "Weekend of November 28–29, 2026"
    click_on "Edit notes"

    assert_selector "h2", text: "PUBLIC TALK"
    assert_selector "h2", text: "WATCHTOWER STUDY"
    assert_text "Follow along and mark your answers in JW Library. Keep anything you want to remember here."
    assert_field "Talk title", placeholder: "The title the speaker announces"
    assert_selector "lexxy-editor", count: 2
    assert_accessible
    capture_screens("weekend-note")

    fill_in "Talk title", with: "Find Refuge in Jehovah"
    fill_in "Speaker", with: "Samuel Mensah"
    write_notes "Notes for Public Talk", "Psalm 91 as a hiding place."
    fill_in "Article title", with: "Stay close to Jehovah"
    click_on "Save notes"

    assert_text "Notes saved."
    assert_selector "h3", text: "Public Talk · Find Refuge in Jehovah"
    assert_text "Speaker: Samuel Mensah"
    assert_text "Psalm 91 as a hiding place."
    assert_selector "h3", text: "Watchtower Study · Stay close to Jehovah"
    assert_accessible
    capture_screens("weekend-note-read")
  end

  private
    # Types into the Lexxy editor with that label, the way a person does: focus it, then type at its end.
    def write_notes(label, text)
      editor = find(:label, label).find(:xpath, "..").find("lexxy-editor [contenteditable='true']")
      editor.click
      editor.send_keys(END_OF_TEXT, text)
    end
end
