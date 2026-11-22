require "application_system_test_case"

# Notes on a phone (docs/design/phone.md, Notes; frames phone-notes.png, phone-note.png and phone-note-menu.png): "+ New ▾"
# beside the title, "All notes ▾" and a search button on one row, each note as a two-line row, and the color filter
# still as swatches. On a note, a back row with its "…" holding Edit note, Pin, Move and Delete; its scriptures and
# details come under the note, and the color swatches are 44px targets.
class PersonalNotesPhoneTest < ApplicationSystemTestCase
  setup do
    sign_in identities(:head)
    personal_notes(:head_return_visit).update!(body: "Why does God allow suffering? What is God's name? " * 4)
    personal_notes(:head_return_visit).tag_with("ministry", by: users(:head))
    visit root_url
    emulate_phone
  end

  teardown do
    cdp("Emulation.clearDeviceMetricsOverride")
    cdp("Emulation.setTouchEmulationEnabled", enabled: false)
  end

  test "the title row has + New ▾ beside the title, and New › Note opens New note" do
    visit notes_url

    heading = find("main h1", text: "Notes")
    new_button = find("button", exact_text: "New")
    assert_operator new_button.evaluate_script("this.getBoundingClientRect().top"), :<, heading.evaluate_script("this.getBoundingClientRect().bottom"), "New isn't beside the title"
    assert_operator new_button.evaluate_script("this.getBoundingClientRect().right"), :<=, evaluate_script("document.documentElement.clientWidth")
    assert_operator new_button.evaluate_script("this.offsetHeight"), :>=, 44
    assert_text "Only you can see these."
    assert_no_text "Your own notes to come back to."
    assert_no_link "New note"

    assert_turbo_idle
    new_button.click
    assert_equal [ "Note", "Collection" ], menu_entries("personal-notes-new-menu")
    all("#personal-notes-new-menu-list [role=menuitem]").each do |item|
      assert_operator item.evaluate_script("this.offsetHeight"), :>=, 44, "#{item.text} is too small to tap"
    end
    assert_accessible
    find("[role=menuitem]", exact_text: "Note").click

    assert_selector "h1", text: "New note"
  end

  test "New › Collection opens the New collection dialog, and All notes ▾ no longer lists it" do
    visit notes_url

    click_on "All notes"
    assert_selector "[role=menuitem]", text: "Quick references"
    assert_no_selector "[role=menuitem]", text: "New collection"
    find("body").send_keys(:escape)

    choose_from_menu "New", "Collection"
    wait_for_dialog
    within("dialog[open]", text: "New collection") do
      fill_in "Name", with: "Convention 2027"
      choose "Notes only"
      assert_accessible
      click_on "Create collection"
    end

    assert_button "Convention 2027"
    assert users(:head).collections.find_by!(name: "Convention 2027").used_in_notes?
  end

  test "pick a collection from the menu" do
    visit notes_url

    assert_no_selector "nav[aria-label=Collections]"
    assert_no_selector "nav[aria-label='My tags']"
    assert_equal evaluate_script("document.documentElement.clientWidth"), evaluate_script("document.documentElement.scrollWidth")

    click_on "All notes"
    assert_selector "[role=menuitem]", text: "#ministry"
    all("[role=menuitem]").each do |item|
      assert_operator item.evaluate_script("this.offsetHeight"), :>=, 44, "#{item.text} is too small to tap"
    end
    assert_accessible
    find("[role=menuitem]", text: "Quick references").click

    assert_selector "main .personal-notes__row", count: 1
    assert_selector "main .personal-notes__row", text: "Daniel 2 image: quick reference"
    assert_accessible

    click_on "Quick references"
    assert_selector "[role=menuitem][aria-current=true]", text: "Quick references"
    capture_screens("phone-notes-menu", viewports: ScreenshotHelper::VIEWPORTS.slice(:phone))
  end

  test "the filter and search share a row, and search reveals the field" do
    visit notes_url

    menu_button = find("button", text: "All notes")
    search_button = find("button[aria-label='Search notes']")
    middle = "(({ top, bottom }) => Math.round((top + bottom) / 2))(this.getBoundingClientRect())"
    assert_equal menu_button.evaluate_script(middle), search_button.evaluate_script(middle), "the filter and search aren't on one row"
    assert_operator search_button.evaluate_script("this.offsetHeight"), :>=, 44
    assert_operator search_button.evaluate_script("this.offsetWidth"), :>=, 44
    assert_equal "false", search_button[:"aria-expanded"]
    assert_no_field "Search titles, collections and tags"

    search_button.click
    assert_equal "true", search_button[:"aria-expanded"]
    field = find_field("Search titles, collections and tags")
    assert_equal field, page.active_element
    assert_accessible
    field.send_keys("Daniel", :enter)

    assert_selector "main .personal-notes__row", count: 1
    assert_selector "main .personal-notes__row", text: "Daniel 2 image: quick reference"
    assert_field "Search titles, collections and tags", with: "Daniel"
    assert_equal "true", find("button[aria-label='Search notes']")[:"aria-expanded"]
  end

  test "a note row has two lines, and no tag Labels" do
    personal_notes(:head_daniel).update!(body: "Head of gold, chest of silver, belly of copper, legs of iron, feet of iron and clay. " * 3)
    personal_notes(:head_daniel).pin_to_top
    visit notes_url

    assert_no_selector "main .note-card"
    within("section[aria-labelledby=pinned-notes]") { assert_selector ".personal-notes__row", text: "Daniel 2 image: quick reference" }
    row = find("main .personal-notes__row", text: "Questions for my return visit")
    assert_selector "main .personal-notes__row", count: 3
    within(row) do
      assert_no_selector ".Label"
      assert_no_text "#ministry"
      assert_selector ".note-dot--green"
      assert_link "Questions for my return visit"
      title = find(".personal-notes__row-title")
      line = find(".personal-notes__row-line")
      assert_operator title.evaluate_script("this.offsetHeight"), :<, 2 * title.evaluate_script("parseFloat(getComputedStyle(this).lineHeight)"), "the title is more than one line"
      assert_operator line.evaluate_script("this.offsetHeight"), :<, 2 * line.evaluate_script("parseFloat(getComputedStyle(this).lineHeight)"), "the muted line is more than one line"
      assert_match(/\Atoday · Why does God allow suffering\?/, line.text)
      assert_operator line.evaluate_script("this.scrollWidth"), :>, line.evaluate_script("this.clientWidth"), "the muted line isn't cut"
      assert_equal "ellipsis", line.evaluate_script("getComputedStyle(this).textOverflow")
    end
    assert_match(/\AQuick references · today · Head of gold/, find("main .personal-notes__row", text: "Daniel 2 image").find(".personal-notes__row-line").text)
    assert_equal evaluate_script("document.documentElement.clientWidth"), evaluate_script("document.documentElement.scrollWidth")
    assert_accessible

    find("main .personal-notes__row a", text: "Daniel 2 image: quick reference").click
    assert_selector "main .note-card h1", text: "Daniel 2 image: quick reference"
  end

  test "on a note, the back row leads to its collection, and its … holds the note's actions" do
    visit note_url(personal_notes(:head_daniel))

    within(".back-row") do
      assert_link "Quick references", href: household_personal_notes_path(household_id: households(:home), collection: collections(:head_quick_references).id)
      assert_selector "button[aria-label='Note actions']"
    end
    assert_no_selector "nav[aria-label=Breadcrumb]"
    assert_no_link "Edit"
    assert_no_button "Pin"
    assert_accessible

    choose_from_menu_button "Note actions"
    assert_equal [ "Edit note", "Pin to Home", "Move to collection…", "—", "Delete note…" ], menu_entries("personal-note-menu")
    all("#personal-note-menu-list [role=menuitem]").each do |item|
      assert_operator item.evaluate_script("this.offsetHeight"), :>=, 44, "#{item.text} is too small to tap"
    end
    assert_accessible
    find("[role=menuitem]", exact_text: "Edit note").click

    assert_selector "main lexxy-editor"
    within(".back-row") { assert_link "Quick references" }

    visit note_url(personal_notes(:head_family_worship))
    within(".back-row") { assert_link "Notes", href: household_personal_notes_path(household_id: households(:home)) }
  end

  test "pin and unpin from the note's …" do
    note = personal_notes(:head_daniel)
    note.pin_to_top
    visit note_url(note)

    choose_from_menu_button "Note actions"
    find("[role=menuitem]", exact_text: "Unpin from Home").click

    # The page refreshes, so the menu names the new state.
    assert_selector "#personal-note-menu-list [role=menuitem]", exact_text: "Pin to Home", visible: :all
    choose_from_menu_button "Note actions"
    assert_selector "[role=menuitem]", exact_text: "Pin to Home"
    assert_not note.reload.pinned?
    find("[role=menuitem]", exact_text: "Pin to Home").click

    assert_selector "#personal-note-menu-list [role=menuitem]", exact_text: "Unpin from Home", visible: :all
    choose_from_menu_button "Note actions"
    assert_selector "[role=menuitem]", exact_text: "Unpin from Home"
    assert note.reload.pinned?
    capture_screens("phone-note-menu", viewports: ScreenshotHelper::VIEWPORTS.slice(:phone))
  end

  test "move a note to a collection from its …" do
    note = personal_notes(:head_family_worship)
    visit note_url(note)

    choose_from_menu_button "Note actions"
    find("[role=menuitem]", exact_text: "Move to collection…").click
    wait_for_dialog
    within("dialog[open]", text: "Move to collection") do
      assert_select "Collection", selected: "None"
      select "Quick references", from: "Collection"
      assert_accessible
      click_on "Move"
    end

    assert_text "Note saved."
    within(".back-row") { assert_link "Quick references" }
    assert_equal collections(:head_quick_references), note.reload.collection
  end

  test "delete a note from its …, which asks first" do
    note = personal_notes(:head_family_worship)
    visit note_url(note)

    choose_from_menu_button "Note actions"
    find("[role=menuitem]", exact_text: "Delete note…").click
    wait_for_dialog
    within("dialog[open]", text: "Delete this note?") do
      assert_accessible
      click_on "Delete note"
    end

    assert_text "Note deleted."
    assert_not PersonalNote.exists?(note.id)
  end

  test "a long collection name and a wider phone still fit" do
    users(:head).collections.add(name: "W" * 40, used_in: "notes")
    visit notes_url

    click_on "All notes"
    find("[role=menuitem]", text: "W" * 40).click

    assert_button "W" * 40
    assert_equal evaluate_script("document.documentElement.clientWidth"), evaluate_script("document.documentElement.scrollWidth"), "the page is wider than the phone"
    assert_operator find_button("W" * 40).evaluate_script("this.getBoundingClientRect().right"), :<=, find("button[aria-label='Search notes']").evaluate_script("this.getBoundingClientRect().left"), "the menu button runs into search"

    emulate_viewport(767, 1024, phone: true)
    visit notes_url
    assert_selector "main .personal-notes__row", count: 3
    assert_no_selector "main .note-card"
  end

  test "filter by color" do
    visit notes_url

    within("[role=group][aria-labelledby=note-color-filter-label]") do
      all("button").each do |swatch|
        assert_operator swatch.evaluate_script("this.offsetHeight"), :>=, 44, "#{swatch.text} is too small to tap"
      end
      click_on "Only green notes"
    end

    assert_selector "main .personal-notes__row", count: 1
    assert_selector "main .personal-notes__row", text: "Questions for my return visit"
    assert_equal "true", find_button("Only green notes")[:"aria-pressed"]
    assert_accessible
  end

  test "open a note, change its color and save" do
    visit notes_url
    click_on "Ideas for family worship"

    assert_selector "main .note-card h1", text: "Ideas for family worship"
    assert_no_selector "main lexxy-editor"
    assert_equal evaluate_script("document.documentElement.clientWidth"), evaluate_script("document.documentElement.scrollWidth")
    assert_accessible
    capture_screens("phone-note")
    emulate_phone

    choose_from_menu_button "Note actions"
    find("[role=menuitem]", exact_text: "Edit note").click
    assert_selector "main lexxy-editor"
    assert_turbo_idle

    all(".color-picker__swatch").each do |swatch|
      assert_operator swatch.evaluate_script("this.offsetWidth"), :>=, 44, "a swatch is too small to tap"
      assert_operator swatch.evaluate_script("this.offsetHeight"), :>=, 44, "a swatch is too small to tap"
    end
    assert_operator find("section[aria-labelledby=note-scriptures]").evaluate_script("this.getBoundingClientRect().top"), :>=,
      find("main .note-card").evaluate_script("this.getBoundingClientRect().bottom"), "the side panel isn't under the note"

    find("label[for=personal_note_color_blue]").click
    assert_selector ".color-picker__chosen", text: "Blue"
    click_on "Save note"

    assert_text "Note saved."
    assert_selector "main .note-card.note-card--blue .note-dot--blue + *", text: "Blue"
    assert_equal "blue", personal_notes(:head_family_worship).reload.color
    choose_from_menu_button "Note actions"
    find("[role=menuitem]", exact_text: "Edit note").click
    assert_selector "main lexxy-editor"
    assert_turbo_idle
    assert_equal evaluate_script("document.documentElement.clientWidth"), evaluate_script("document.documentElement.scrollWidth")
    assert_accessible
    capture_screens("phone-note-edit")
    emulate_phone

    visit notes_url
    assert_selector "main .personal-notes__row .note-dot--blue ~ .personal-notes__row-text", text: "Ideas for family worship"
    capture_screens("phone-notes")
  end

  private
    def notes_url
      household_personal_notes_url(household_id: households(:home))
    end

    def note_url(note)
      household_personal_note_url(household_id: households(:home), id: note)
    end

    def emulate_phone
      emulate_viewport(*ScreenshotHelper::VIEWPORTS[:phone], phone: true)
      emulate_touch(true)
    end

    # Opens the menu behind an icon-only button, named by its aria-label.
    def choose_from_menu_button(label)
      assert_turbo_idle
      find("button[aria-label='#{label}']").click
    end
end
