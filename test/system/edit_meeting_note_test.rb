require "application_system_test_case"

class EditMeetingNoteTest < ApplicationSystemTestCase
  # Moves the caret to the end of the editor's text: Cmd+Down on a Mac, Ctrl+End on Linux CI.
  END_OF_TEXT = RUBY_PLATFORM.include?("darwin") ? [ :command, :down ] : [ :control, :end ]

  setup do
    sign_in identities(:head)
  end

  test "write a talk title and notes, add a second Living as Christians part, save, and see them on the read view" do
    visit household_meeting_note_url(household_id: households(:home), id: meeting_notes(:head_midweek))
    click_on "Edit notes"

    assert_selector "h1", text: "Life and Ministry"
    fill_in "Title", with: "Jehovah holds on to us"
    write_notes "Notes for Talk", " The right hand."
    fill_in "Part title", with: "Local needs"
    click_on "Add another part"
    within("fieldset", text: "Living as Christians part 2") do
      assert_selector ":focus", visible: true
      fill_in "Part title", with: "Be generous"
    end
    write_notes "Notes for Living as Christians part 2", "Give quietly."
    click_on "Save notes"

    assert_text "Notes saved."
    assert_selector "h1", text: "Life and Ministry"
    assert_selector "h3", text: "Talk · Jehovah holds on to us"
    assert_text "not just to watch from a distance. The right hand."
    assert_selector "h3", text: "Living as Christians part · Local needs"
    assert_selector "h3", text: "Living as Christians part · Be generous"
    assert_text "Give quietly."
    assert_equal [ "Talk · Jehovah holds on to us", "Living as Christians part · Local needs",
                   "Living as Christians part · Be generous", "Congregation Bible Study" ], all("main h3").map(&:text)
  end

  test "remove a Living as Christians part" do
    meeting_note_parts(:head_living_part).update!(title: "Local needs")
    visit edit_household_meeting_note_url(household_id: households(:home), id: meeting_notes(:head_midweek))

    click_on "Add another part"
    find("button[aria-label='Remove Living as Christians part 2']").click
    assert_no_selector "fieldset", text: "Living as Christians part 2"
    find("button[aria-label='Remove Living as Christians part 1']").click
    assert_no_field "Part title"
    assert_selector ":focus", text: "Add another part"
    click_on "Save notes"

    assert_text "Notes saved."
    assert_no_text "Local needs"
    assert_equal 5, meeting_notes(:head_midweek).parts.count
  end

  test "the edit page passes assert_accessible" do
    visit edit_household_meeting_note_url(household_id: households(:home), id: meeting_notes(:head_midweek))

    assert_selector "lexxy-editor", count: 5
    assert_accessible
    capture_screens("edit-meeting-note")

    click_on "Add another part"
    click_on "Add another part"
    assert_selector "fieldset", text: "Living as Christians part 3"
    ids = all("main [id]", visible: :all).map { it[:id] }
    assert_empty ids.tally.select { |_, count| count > 1 }.keys, "ids repeat after cloning parts"
    assert_accessible
    capture_screens("edit-meeting-note-two-parts", scroll_to: "[data-controller='living-parts']")
  end

  private
    # Types into the Lexxy editor with that label, the way a person does: focus it, then type at its end.
    def write_notes(label, text)
      editor = find(:label, label).find(:xpath, "..").find("lexxy-editor [contenteditable='true']")
      editor.click
      editor.send_keys(END_OF_TEXT, text)
    end
end
