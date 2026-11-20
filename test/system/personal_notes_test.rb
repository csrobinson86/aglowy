require "application_system_test_case"

class PersonalNotesTest < ApplicationSystemTestCase
  # Moves the caret to the end of the editor's text: Cmd+Down on a Mac, Ctrl+End on Linux CI.
  END_OF_TEXT = RUBY_PLATFORM.include?("darwin") ? [ :command, :down ] : [ :control, :end ]
  EDITOR = "lexxy-editor[name='personal_note[body]']"
  PICKER = "[data-controller='scripture-picker']"
  NEW_TAG_EDITOR = "#tag_editor_personal_note"

  setup { sign_in identities(:head) }

  test "create a note in a shared collection, link scriptures with the picker and by typing, tag it, find it by tag and by title" do
    visit household_personal_notes_url(household_id: households(:home))

    assert_selector "h1", text: "Notes"
    assert_selector "aside nav [aria-current=page]", text: "Notes"
    assert_no_selector "action-menu.personal-notes__menu"
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
    assert_selector "main h1", text: "Prayer: what I learned this week"
    assert_selector "main .lexxy-content .scripture-link", text: "Philippians 4:6"
    assert_selector "main .lexxy-content .scripture-link", text: "Matthew 6:9"
    within("section[aria-labelledby=note-scriptures]") do
      assert_link "Philippians 4:6"
      assert_link "Matthew 6:9"
    end
    within("nav[aria-label=Breadcrumb]") { assert_link "Bible questions" }

    click_on "Edit"
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
    visit edit_household_personal_note_url(household_id: households(:home), id: personal_notes(:head_family_worship))

    within("fieldset", text: "Color") do
      assert_selector ".color-picker__chosen", text: "None"
      find("input[type=radio][value=none]", visible: :all).send_keys(:right)
      assert_selector ".color-picker__chosen", text: "Yellow"
    end
    assert find_field("Yellow", visible: :all).checked?
    click_on "Save note"

    assert_text "Note saved."
    assert_selector "main .note-card.note-card--yellow .note-dot--yellow + *", text: "Yellow"
    assert_accessible

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

    users(:head).update!(appearance: "dark")
    visit household_personal_notes_url(household_id: households(:home))
    assert_selector "body[data-color-mode=dark]"
    assert_accessible
    visit household_personal_note_url(household_id: households(:home), id: personal_notes(:head_family_worship))
    assert_selector "main .note-card.note-card--yellow"
    assert_accessible
  end

  test "on New note, choosing Red recolors the card before any save, and Save note saves it red" do
    visit new_household_personal_note_url(household_id: households(:home))
    assert_selector "main .note-card.note-card--none"
    assert_no_selector "main .note-card [data-note-color-name]", visible: :all
    fill_in "Title", with: "Patience"

    within("fieldset", text: "Color") do
      assert_selector ".color-picker__chosen", text: "None"
      find("label[for=personal_note_color_red]").click
      assert_selector ".color-picker__chosen", text: "Red"
    end
    assert_selector "main .note-card.note-card--red", text: "Red note"
    assert_no_selector "main .note-card.note-card--none"
    assert_equal "rgba(255, 118, 118, 0.3)", background_color("main .note-card")
    assert_equal "rgb(255, 118, 118)", background_color("label[for=personal_note_color_red]")
    assert_not users(:head).personal_notes.exists?(title: "Patience")
    assert_accessible
    capture_screens("note-new")

    click_on "Save note"
    assert_text "Note saved."
    assert_selector "main h1", text: "Patience"
    assert_selector "main .note-card.note-card--red .note-dot--red + *", text: "Red"
    assert users(:head).personal_notes.find_by!(title: "Patience").color_red?
  end

  # docs/design/notes.md, A note: Tags on a new note; docs/design/tags.md, The tag editor, on a note that isn't saved yet.
  test "on New note, add an existing tag from the suggestions and create a new one, remove one, Save note, then see the tags on the read view" do
    visit new_household_personal_note_url(household_id: households(:home))
    fill_in "Title", with: "Preparing my talk"

    find_field("Add a tag").send_keys("minis")
    find("[role=option]", text: "#ministry").click
    within(NEW_TAG_EDITOR) { assert_selector "span.Label", text: "#ministry" }
    assert_selector "#{NEW_TAG_EDITOR} input:focus"
    find_field("Add a tag").send_keys("Talk Prep", :enter)
    within(NEW_TAG_EDITOR) { assert_selector "span.Label", text: "#Talk Prep" }
    find_field("Add a tag").send_keys("family")
    find("[role=option]", text: 'Create "#family"').click
    within(NEW_TAG_EDITOR) do
      assert_selector "span.Label", text: "#family"
      find("button[aria-label='Remove tag family']").click
      assert_no_selector "span.Label", text: "#family"
      assert_selector "span.Label", count: 2
      assert_no_selector "a.Label"
    end
    assert_not users(:head).personal_notes.exists?(title: "Preparing my talk")
    assert_accessible
    capture_screens("note-new-tags", scroll_to: NEW_TAG_EDITOR)

    click_on "Save note"
    assert_text "Note saved."
    assert_selector "main h1", text: "Preparing my talk"
    within("main .note-card") do
      assert_link "#ministry"
      assert_link "#talk-prep"
      assert_no_link "#family"
    end
    assert_equal %w[ ministry talk-prep ], users(:head).personal_notes.find_by!(title: "Preparing my talk").tags.map(&:name).sort
    assert_accessible
  end

  test "on New note, a refused save keeps the tags as typed, and saving again saves them" do
    visit new_household_personal_note_url(household_id: households(:home))
    fill_in "Title", with: "Patience"
    find_field("Add a tag").send_keys("Prayer", :enter)
    within(NEW_TAG_EDITOR) { assert_selector "span.Label", text: "#Prayer" }
    find_field("Add a tag").send_keys("###", :enter)
    within(NEW_TAG_EDITOR) { assert_selector "span.Label", text: "####" }
    click_on "Save note"

    assert_text %(Couldn't add the tag "###": Name needs at least one letter or number)
    assert_equal "Patience", find_field("Title").value
    within(NEW_TAG_EDITOR) do
      assert_selector "span.Label", text: "#Prayer"
      assert_selector "span.Label", text: "####"
    end
    assert_not users(:head).personal_notes.exists?(title: "Patience")
    assert_accessible
    capture_screens("note-new-tags-refused")

    find("#{NEW_TAG_EDITOR} button[aria-label='Remove tag ###']").click
    click_on "Save note"
    assert_text "Note saved."
    within("main .note-card") { assert_link "#prayer" }
    assert_equal [ "prayer" ], users(:head).personal_notes.find_by!(title: "Patience").tags.map(&:name)
  end

  test "on a saved yellow note, choosing Blue recolors the card at once; leaving without saving keeps it yellow" do
    note = personal_notes(:head_family_worship)
    note.update!(color: "yellow")
    visit edit_household_personal_note_url(household_id: households(:home), id: note)
    assert_selector "main .note-card.note-card--yellow", text: "Yellow note"

    find("label[for=personal_note_color_blue]").click
    assert_selector "main .note-card.note-card--blue", text: "Blue note"
    assert_no_selector "main .note-card.note-card--yellow"
    assert_no_text "Yellow note"
    within("fieldset", text: "Color") { assert_selector ".color-picker__chosen", text: "Blue" }

    find("label[for=personal_note_color_none]").click
    assert_selector "main .note-card.note-card--none"
    assert_no_selector "main .note-card [data-note-color-name]", visible: :all
    find("label[for=personal_note_color_blue]").click
    assert_selector "main .note-card.note-card--blue [data-note-color-name]", text: "Blue note", count: 1

    within("nav[aria-label=Breadcrumb]") { click_on "Notes" }
    assert_selector "h1", text: "Notes"
    assert note.reload.color_yellow?
    go_back
    within("fieldset", text: "Color") { assert_selector ".color-picker__chosen", text: "Yellow" }
    assert_selector "main .note-card.note-card--yellow", text: "Yellow note"

    visit household_personal_notes_url(household_id: households(:home))
    click_on "Ideas for family worship"
    assert_selector "main .note-card.note-card--yellow h1", text: "Ideas for family worship"
    click_on "Edit"
    within("fieldset", text: "Color") { assert_selector ".color-picker__chosen", text: "Yellow" }
    assert_selector "main .note-card.note-card--yellow"
    assert_no_selector "main .note-card.note-card--blue"
    assert find_field("Yellow", visible: :all).checked?
  end

  test "the new colors on the list, the filter, a note's page and Home, light and dark" do
    personal_notes(:head_return_visit).update!(color: "red")
    personal_notes(:head_daniel).update!(color: "brown")
    personal_notes(:head_family_worship).update!(color: "gray")
    personal_notes(:head_family_worship).pin_to_top

    visit household_personal_notes_url(household_id: households(:home))
    assert_selector "main .note-card.note-card--gray", text: "Ideas for family worship"
    assert_equal "rgba(200, 200, 200, 0.3)", background_color("main .note-card--gray")
    assert_button "Only red notes"
    assert_button "Only brown notes"
    assert_button "Only gray notes"
    assert_equal "rgb(221, 170, 123)", background_color("button[value=brown]")
    assert_accessible
    capture_screens("notes-colors")

    click_on "Only gray notes"
    assert_selector "button[aria-pressed=true]", text: "Only gray notes"
    assert_selector "main .note-card", count: 1
    assert_selector "main .note-card", text: "Ideas for family worship"

    visit household_root_url(household_id: households(:home))
    assert_equal "rgb(200, 200, 200)", background_color(".note-dot--gray")

    %w[ light dark ].each do |appearance|
      users(:head).update!(appearance:)
      visit household_personal_notes_url(household_id: households(:home))
      assert_selector "body[data-color-mode=#{appearance}]"
      assert_accessible
      %i[ head_return_visit head_daniel head_family_worship ].each do |name|
        visit household_personal_note_url(household_id: households(:home), id: personal_notes(name))
        assert_selector "main .note-card.note-card--#{personal_notes(name).color}"
        assert_accessible
      end
    end

    users(:head).update!(appearance: "auto")
    visit household_personal_note_url(household_id: households(:home), id: personal_notes(:head_return_visit))
    capture_screens("note-colors")
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

  # docs/design/notes.md, A note: the read view, then Edit, which saves or cancels back to it (frames note-read.png and
  # note-editing.png).
  test "open a note to read it, Edit, change the title, Save note and come back to it; Edit then Cancel changes nothing" do
    note = personal_notes(:head_daniel)
    note.body = "<p>Head of gold. Read Daniel 2:44</p>"
    note.link_scriptures
    note.save!
    note.tag_with("ministry", by: users(:head))
    visit household_personal_notes_url(household_id: households(:home))

    click_on "Daniel 2 image: quick reference"
    assert_selector "main .note-card.note-card--orange h1", text: "Daniel 2 image: quick reference"
    within("main .note-card") do
      assert_text "Orange"
      assert_link "Quick references"
      assert_link "#ministry"
      assert_text "Head of gold."
      assert_link "Daniel 2:44"
    end
    assert_no_selector "main input:not([type=hidden]), main select, main lexxy-editor"
    assert_accessible
    capture_screens("note-read")

    click_on "Edit"
    assert_selector EDITOR
    assert_turbo_idle
    assert_accessible
    capture_screens("note-editing")
    fill_in "Title", with: "Daniel 2: the image"
    click_on "Save note"

    assert_text "Note saved."
    assert_selector "main h1", text: "Daniel 2: the image"
    assert_no_selector EDITOR
    assert_equal "Daniel 2: the image", note.reload.title

    click_on "Edit"
    fill_in "Title", with: "Not kept"
    find("label[for=personal_note_color_blue]").click
    click_on "Cancel"

    assert_selector "main .note-card.note-card--orange h1", text: "Daniel 2: the image"
    assert_no_selector EDITOR
    assert_equal "Daniel 2: the image", note.reload.title
    assert note.color_orange?
  end

  test "a title with <b> shows as text on the read view" do
    note = personal_notes(:head_family_worship)
    note.update!(title: "<b>Bold</b> plans")

    visit household_personal_note_url(household_id: households(:home), id: note)

    assert_selector "main h1", text: "<b>Bold</b> plans"
    assert_no_selector "main h1 b"
  end

  test "Edit in two windows: the second save, with a new color and tag, is refused, shows what it wrote, and the tag is on the note anyway" do
    note = personal_notes(:head_daniel)
    edit_url = edit_household_personal_note_url(household_id: households(:home), id: note)
    visit edit_url
    assert_selector EDITOR

    other = open_new_window
    within_window(other) do
      visit edit_url
      fill_in "Title", with: "Saved in the other window", fill_options: { clear: :backspace }
      click_on "Save note"
      assert_text "Note saved."
    end
    other.close

    fill_in "Title", with: "My title"
    find("label[for=personal_note_color_blue]").click
    find_field("Add a tag").send_keys("family", :enter)
    within("[id^=tag_editor_personal_note]") { assert_selector "a.Label", text: "#family" }
    editable = find("#{EDITOR} [contenteditable='true']")
    editable.click
    find("lexxy-toolbar button[name=bold]").click
    editable.send_keys("My bold point")
    click_on "Save note"

    assert_text "This note changed after you started editing, so your changes weren't saved. It's shown as it is now. What you wrote is below."
    assert_equal "Saved in the other window", find_field("Title").value
    assert_selector "main .note-card.note-card--orange"
    within("section[aria-labelledby=what-you-wrote]") do
      assert_text "My title"
      assert_selector ".note-dot--blue + *", text: "Blue"
      assert_selector ".Label", text: "#family"
      assert_selector ".lexxy-content strong", text: "My bold point"
      assert_selector "clipboard-copy[aria-label='Copy text']"
    end
    within("[id^=tag_editor_personal_note]") { assert_selector "a.Label", text: "#family" }
    note.reload
    assert_equal "Saved in the other window", note.title
    assert note.color_orange?
    assert_equal [ "family" ], note.tags.map(&:name)
    assert_accessible
    capture_screens("note-refused", scroll_to: "section[aria-labelledby=what-you-wrote]")

    click_on "Save note"
    assert_text "Note saved."
    assert_selector "main h1", text: "Saved in the other window"
  end

  test "in one window, adding a tag then Save note isn't refused" do
    note = personal_notes(:head_daniel)
    visit edit_household_personal_note_url(household_id: households(:home), id: note)

    find_field("Add a tag").send_keys("prayer", :enter)
    within("[id^=tag_editor_personal_note]") { assert_selector "a.Label", text: "#prayer" }
    fill_in "Title", with: "Daniel 2, tagged"
    click_on "Save note"

    assert_text "Note saved."
    assert_selector "main h1", text: "Daniel 2, tagged"
    within("main .note-card") { assert_link "#prayer" }
    assert_equal "Daniel 2, tagged", note.reload.title
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
