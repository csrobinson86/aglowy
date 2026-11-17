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
    assert_no_selector "action-menu#personal-notes-menu"
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

  test "pick Yellow with the keyboard, save, see a yellow card and filter by it, in light and dark" do
    visit household_personal_note_url(household_id: households(:home), id: personal_notes(:head_family_worship))

    within("fieldset", text: "Color") do
      assert_selector ".note-color-picker__chosen", text: "None"
      find("input[type=radio][value=none]", visible: :all).send_keys(:right)
      assert_selector ".note-color-picker__chosen", text: "Yellow"
    end
    assert find_field("Yellow", visible: :all).checked?
    click_on "Save note"

    assert_text "Note saved."
    assert_selector "main .note-card.note-card--yellow", text: "Yellow note"
    assert find_field("Yellow", visible: :all).checked?
    assert_accessible
    capture_screens("note-colors")

    visit household_personal_notes_url(household_id: households(:home))
    assert_selector "main .note-card.note-card--yellow", text: "Ideas for family worship"
    click_on "Only yellow notes"
    assert_selector "button[aria-pressed=true]", text: "Only yellow notes"
    assert_selector "main .note-card", count: 1
    assert_selector "main .note-card", text: "Ideas for family worship"
    assert_accessible

    click_on "Any color"
    assert_selector "main .note-card", count: 3
    assert_selector "main .note-card.note-card--green", text: "Questions for my return visit"
    assert_selector "main .note-card.note-card--orange", text: "Daniel 2 image: quick reference"
    capture_screens("notes-colors")

    users(:head).update!(appearance: "dark")
    visit household_personal_notes_url(household_id: households(:home))
    assert_selector "body[data-color-mode=dark]"
    assert_accessible
    visit household_personal_note_url(household_id: households(:home), id: personal_notes(:head_family_worship))
    assert_selector "main .note-card.note-card--yellow"
    assert_accessible
  end

  test "pin a note from its page, see it under Pinned and on Home, and unpin it from its card" do
    visit household_personal_note_url(household_id: households(:home), id: personal_notes(:head_daniel))
    click_on "Pin"

    assert_selector "button[aria-pressed=true]", text: "Pinned"
    assert personal_notes(:head_daniel).reload.pinned?
    assert_accessible
    capture_screens("note-pinned")

    visit household_personal_notes_url(household_id: households(:home))
    within("section[aria-labelledby=pinned-notes]") { assert_selector ".note-card", count: 1, text: "Daniel 2 image: quick reference" }
    within("section[aria-labelledby=all-notes]") { assert_no_text "Daniel 2 image" }
    assert_accessible
    capture_screens("notes-pinned")

    visit household_root_url(household_id: households(:home))
    within(".Box", text: "Pinned notes") do
      assert_selector ".note-dot--orange"
      assert_link "Daniel 2 image: quick reference"
      assert_link "All notes"
    end
    assert_accessible
    capture_screens("home-pinned-notes", scroll_to: ".Box:has(.note-dot)")

    visit household_personal_notes_url(household_id: households(:home))
    within("section[aria-labelledby=pinned-notes] .note-card") { click_on "Unpin" }

    assert_no_selector "section[aria-labelledby=pinned-notes]"
    within("section[aria-labelledby=all-notes]") { assert_selector ".note-card", text: "Daniel 2 image: quick reference" }
    within("nav[aria-label=Collections]") { assert_link "Quick references" }
    assert_text "My tags"
    assert_not personal_notes(:head_daniel).reload.pinned?
    assert_accessible
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
