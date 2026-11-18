require "application_system_test_case"

class MeetingNotesTest < ApplicationSystemTestCase
  END_OF_TEXT = RUBY_PLATFORM.include?("darwin") ? [ :command, :down ] : [ :control, :end ]

  test "start this week's Life and Ministry note from the list and land on it" do
    travel_to Time.utc(2026, 11, 25, 12) # a week with no notes yet
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))
    within("nav[aria-label='Main']") { click_on "Notes" }
    within("nav[aria-label='Notes, meeting notes and bookmarks']") { click_on "Meeting notes" }

    assert_selector "h1", text: "Notes"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Notes"
    assert_selector "button", text: "Start notes", count: 2
    assert_accessible
    capture_screens("meeting-notes-not-started")
    within(".Box", text: /\ALife and Ministry/) { click_on "Start notes" }

    assert_selector "h1", text: "Life and Ministry"
    assert_text "Week of November 23–29, 2026"
    assert_text "Nothing written yet."
    assert_equal users(:head).meeting_notes.find_by!(kind: "midweek", week_of: Date.new(2026, 11, 23)).id, current_path.split("/").last
  end

  test "from Notes, open the Meeting notes tab, filter it, switch to Shared and back, and follow a note's breadcrumb back to Notes" do
    travel_to Time.utc(2026, 11, 18, 12)
    users(:head).start_meeting_note(kind: "weekend", week_of: Date.new(2026, 11, 9))
    earlier = users(:head).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    earlier.share_with(households(:home))
    users(:spouse).start_meeting_note(kind: "weekend", week_of: Date.new(2026, 11, 9)).share_with(households(:home))
    sign_in identities(:head)
    visit household_personal_notes_url(household_id: households(:home))

    within("nav[aria-label='Notes, meeting notes and bookmarks']") { click_on "Meeting notes" }
    assert_selector "nav[aria-label='Notes, meeting notes and bookmarks'] a[aria-current='page']", text: "Meeting notes"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Notes"
    assert_no_selector "nav[aria-label='Main'] a", text: "Meeting notes"
    assert_selector "h2", text: "This week"
    assert_selector ".Box-row", count: 2
    assert_accessible
    capture_screens("notes-meeting-notes")

    within(".Layout-sidebar nav[aria-label='Meetings']") { click_on "Life and Ministry" }
    assert_selector ".Layout-sidebar nav[aria-label='Meetings'] a[aria-current='page']", text: "Life and Ministry"
    assert_no_selector "h2", text: "This week"
    assert_selector ".Box-row", count: 2
    assert_no_selector ".Box-row", text: "Weekend meeting"

    within("ul[aria-label='Show']") { click_on "Shared in The Head Family" }
    assert_selector "ul[aria-label='Show'] a[aria-current='true']", text: "Shared in The Head Family"
    assert_selector ".Box-row", count: 1
    assert_selector ".Box-row", text: /Life and Ministry.*Hannah Head/m
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Notes"
    assert_accessible

    within(".Layout-sidebar nav[aria-label='Meetings']") { click_on "All meetings" }
    assert_selector ".Box-row", count: 2
    assert_selector "h2", text: "This week"
    capture_screens("notes-meeting-notes-shared")
    within("ul[aria-label='Show']") { click_on "Mine" }
    assert_selector "ul[aria-label='Show'] a[aria-current='true']", text: "Mine"
    assert_selector "h2", text: "This week"

    users(:head).update!(appearance: "dark")
    visit current_url
    assert_selector "body[data-color-mode=dark]"
    assert_accessible

    within(".Box-row", text: "Week of November 9–15, 2026") { click_on "Life and Ministry" }
    assert_selector "h1", text: "Life and Ministry"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Notes"
    within("nav[aria-label='Breadcrumb']") { click_on "Meeting notes" }
    assert_selector "nav[aria-label='Notes, meeting notes and bookmarks'] a[aria-current='page']", text: "Meeting notes"
    page.go_back
    within("nav[aria-label='Breadcrumb']") { click_on "Notes" }
    assert_selector "nav[aria-label='Notes, meeting notes and bookmarks'] a[aria-current='page']", text: /\ANotes/
    assert_current_path household_personal_notes_path(household_id: households(:home))
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

  test "the owner's midweek note lists their parts that week, and each opens its part" do
    travel_to Time.utc(2026, 11, 18, 12)
    MeetingPart.delete_all # The fixture parts are dated from the real today, so one could land in this week.
    users(:head).meeting_parts.create!(kind: "starting_a_conversation", meeting_on: Date.new(2026, 11, 19), minutes: 3, topic: "Hope")
    talk = users(:head).meeting_parts.create!(kind: "talk", meeting_on: Date.new(2026, 11, 19), minutes: 5, topic: "Why we can trust the Bible")
    sign_in identities(:head)

    visit household_meeting_note_url(household_id: households(:home), id: meeting_notes(:head_midweek))
    assert_link "Your part this week: Starting a Conversation, 3 min"
    assert_accessible
    capture_screens("meeting-note-parts")

    click_on "Your part this week: Talk, 5 min"

    assert_current_path household_meeting_part_path(household_id: households(:home), id: talk)
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
