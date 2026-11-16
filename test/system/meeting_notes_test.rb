require "application_system_test_case"

class MeetingNotesTest < ApplicationSystemTestCase
  END_OF_TEXT = RUBY_PLATFORM.include?("darwin") ? [ :command, :down ] : [ :control, :end ]

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

  test "a note saved with a scripture link shows the link" do
    psalm = Bible::Reference.find("19:37:8-9")
    meeting_note_parts(:head_talk).update!(notes: "<p>Let go of anger, even when it feels justified. #{scripture_attachment(psalm.id)}</p>")
    sign_in identities(:head)

    # Lexxy loads the link into the editor, and saving sends it back.
    visit edit_household_meeting_note_url(household_id: households(:home), id: meeting_notes(:head_midweek))
    editor = find("lexxy-editor#meeting_note_parts_attributes_0_notes")
    assert_selector "##{editor[:id]} .scripture-link", text: "Psalm 37:8, 9"
    capture_screens("meeting-note-scripture-link-editor", scroll_to: "##{editor[:id]}")
    # In the editor the link is styled as one but isn't clickable: clicking it opens no tab.
    find("##{editor[:id]} .scripture-link").ancestor("action-text-attachment").click
    assert_equal 1, windows.size
    click_on "Save notes"

    assert_text "Notes saved."
    link = find("main a.scripture-link", text: "Psalm 37:8, 9")
    assert_equal psalm.jw_url, link[:href]
    assert_equal "_blank", link[:target]
    assert_accessible
    capture_screens("meeting-note-scripture-link", scroll_to: "main a.scripture-link")
  end

  test "a reference typed in a part's notes is linked when the note is saved" do
    sign_in identities(:head)
    visit edit_household_meeting_note_url(household_id: households(:home), id: meeting_notes(:head_midweek))
    editor = find("lexxy-editor#meeting_note_parts_attributes_0_notes [contenteditable='true']")
    editor.click
    editor.send_keys(END_OF_TEXT, :enter, "Keep on the watch, matt 24:14")
    click_on "Save notes"

    assert_text "Notes saved."
    link = find("main a.scripture-link", text: "Matthew 24:14")
    assert_equal Bible::Reference.find("40:24:14").jw_url, link[:href]
    assert_accessible
    capture_screens("scripture-linked-on-save", scroll_to: "main a.scripture-link")
  end

  test "the notes editor has no upload buttons, and starts no upload even for the one attachment type it permits" do
    sign_in identities(:head)
    visit edit_household_meeting_note_url(household_id: households(:home), id: meeting_notes(:head_midweek))
    assert_selector "lexxy-editor[connected]", minimum: 1
    assert_selector "lexxy-toolbar button[name=bold]", minimum: 1
    assert_no_selector "lexxy-toolbar button[name=image]"
    assert_no_selector "lexxy-toolbar button[name=file]"

    accepted = page.evaluate_script(<<~JS)
      document.querySelector("lexxy-editor").dispatchEvent(new CustomEvent("lexxy:file-accept", {
        cancelable: true, detail: { file: new File([ "x" ], "x", { type: "application/vnd.actiontext.scripture" }) }
      }))
    JS

    assert_equal false, accepted
  end
end
