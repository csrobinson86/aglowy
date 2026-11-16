require "application_system_test_case"

class PersonalNotesTest < ApplicationSystemTestCase
  # Moves the caret to the end of the editor's text: Cmd+Down on a Mac, Ctrl+End on Linux CI.
  END_OF_TEXT = RUBY_PLATFORM.include?("darwin") ? [ :command, :down ] : [ :control, :end ]
  EDITOR = "lexxy-editor[name='personal_note[body]']"
  PICKER = "[data-controller='scripture-picker']"

  setup { sign_in identities(:head) }

  test "create a note in a shared collection, link scriptures with the picker and by typing, tag it, find it by tag and by title" do
    visit household_personal_notes_url(household_id: households(:home))

    assert_selector "h1", text: "Notes"
    assert_selector "aside nav [aria-current=page]", text: "Notes"
    assert_accessible

    click_on "New note", match: :first
    assert_selector "h1", text: "New note"
    assert_accessible
    fill_in "Title", with: "Prayer: what I learned this week"
    select "Bible questions", from: "Collection"

    editable = find("#{EDITOR} [contenteditable='true']")
    editable.click
    editable.send_keys(END_OF_TEXT, "Pray specifically. ")
    find("lexxy-toolbar button[name=scripture]").click
    within(PICKER) do
      find("[role=option]", text: /\APhilippians\b/).click
      within(".scripture-picker__chapters") { click_on "4" }
      within(".scripture-picker__verses") { click_on "6" }
      click_on "Insert"
    end
    assert_no_selector PICKER
    find("#{EDITOR} [contenteditable='true']").send_keys(END_OF_TEXT, " and Matthew 6:9 as a model.")
    click_on "Save note"

    assert_text "Note saved."
    assert_selector "#{EDITOR} .scripture-link", text: "Philippians 4:6"
    assert_selector "#{EDITOR} .scripture-link", text: "Matthew 6:9"
    within("section[aria-labelledby=note-scriptures]") do
      assert_link "Philippians 4:6"
      assert_link "Matthew 6:9"
    end
    within("nav[aria-label=Breadcrumb]") { assert_link "Bible questions" }

    find_field("Add a tag").send_keys("Prayer", :enter)
    within("[id^=tag_editor_personal_note]") { assert_selector "a.Label", text: "#prayer" }
    assert_accessible
    capture_screens("note")

    visit household_personal_notes_url(household_id: households(:home))
    within("nav[aria-label='My tags']") { click_on "#prayer" }
    assert_selector "main .note-card", count: 1
    assert_selector "main .note-card", text: "Prayer: what I learned this week"

    visit household_personal_notes_url(household_id: households(:home))
    fill_in "Search titles, collections and tags", with: "learned\n"
    assert_selector "main .note-card", count: 1
    assert_selector "main .note-card", text: "Prayer: what I learned this week"

    visit household_personal_notes_url(household_id: households(:home))
    assert_selector "main .note-card", text: "Bible questions · 2 scriptures"
    assert_accessible
    capture_screens("notes")
  end

  test "delete a note after the dialog, on a phone, where the details come under the note" do
    visit household_personal_note_url(household_id: households(:home), id: personal_notes(:head_family_worship))
    emulate_viewport(*ScreenshotHelper::VIEWPORTS[:phone], phone: true)

    click_on "Delete note"
    within("dialog[open]") { click_on "Delete note" }

    assert_text "Note deleted."
    assert_no_text "Ideas for family worship"
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "an empty Notes page" do
    sign_in identities(:eli)
    visit household_personal_notes_url(household_id: households(:home))

    assert_text "No notes yet."
    assert_link "New note"
    assert_accessible
    capture_screens("notes-empty")
  end
end
