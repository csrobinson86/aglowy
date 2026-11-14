require "application_system_test_case"

class SessionNotesTest < ApplicationSystemTestCase
  # Moves the caret to the end of the editor's text: Cmd+Down on a Mac, Ctrl+End on Linux CI.
  END_OF_TEXT = RUBY_PLATFORM.include?("darwin") ? [ :command, :down ] : [ :control, :end ]

  setup do
    sign_in identities(:head)
  end

  test "write notes on the schedule form and see them on the session page" do
    visit new_household_family_study_url(household_id: households(:home))

    fill_in "What will you study?", with: "Proverbs 3"
    fill_in "Date", with: 7.days.from_now.to_date
    fill_in "Starts", with: Time.zone.parse("19:00")
    fill_in "Ends", with: Time.zone.parse("19:45")
    write_notes "Questions about trusting Jehovah"
    capture_screens("schedule-study-notes")
    click_on "Schedule study"

    assert_text "Your family study is scheduled."
    click_on "Proverbs 3"

    assert_selector "h1", text: "Proverbs 3"
    assert_selector ".lexxy-content", text: "Questions about trusting Jehovah"
    assert_no_text "No notes yet"
  end

  test "edit them" do
    study_session = family_study_sessions(:one_off_first)
    study_session.update!(notes: "<p>Read chapter 1</p>")
    visit household_family_study_session_url(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)

    click_on "Edit notes"
    assert_selector "h1", text: "Edit notes"
    assert_selector "label", text: "Notes"
    assert_accessible
    capture_screens("session-notes")

    write_notes " and talk about it"
    click_on "Save notes"

    assert_text "Notes saved."
    assert_selector "h1", text: "Draw Close to Jehovah, chapter 1"
    assert_text "Read chapter 1 and talk about it"
    assert_accessible
    capture_screens("session-notes-filled")
  end

  private
    # Types into Lexxy the way a person does: focus the editable area, then type at its end.
    def write_notes(text)
      editor = find("lexxy-editor [contenteditable='true']")
      editor.click
      editor.send_keys(END_OF_TEXT, text)
    end
end
