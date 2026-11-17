require "application_system_test_case"

# Notes on a phone (docs/design/notes.md, Pages and routes; frame phone-notes.png): collections and tags folded into
# the "All notes ▾" menu, cards one per row with a one-line preview, and the color filter still as swatches. On a note's
# page its scriptures and details come under the note, and the color swatches are 44px targets.
class PersonalNotesPhoneTest < ApplicationSystemTestCase
  setup do
    sign_in identities(:head)
    personal_notes(:head_return_visit).update!(body: "Why does God allow suffering? What is God's name? " * 4)
    visit root_url
    emulate_viewport(*ScreenshotHelper::VIEWPORTS[:phone], phone: true)
    emulate_touch(true)
  end

  teardown do
    cdp("Emulation.clearDeviceMetricsOverride")
    cdp("Emulation.setTouchEmulationEnabled", enabled: false)
  end

  test "pick a collection from the menu" do
    visit notes_url

    assert_no_selector "nav[aria-label=Collections]"
    assert_no_selector "nav[aria-label='My tags']"
    assert_equal 1, all("main .note-card").map { it.evaluate_script("this.getBoundingClientRect().left") }.uniq.size, "the cards aren't one per row"
    preview = find("main .note-card", text: "Questions for my return visit").find(".note-card__preview")
    assert_operator preview.evaluate_script("this.offsetHeight"), :<, 2 * preview.evaluate_script("parseFloat(getComputedStyle(this).lineHeight)"), "the preview is more than one line"
    assert_equal evaluate_script("document.documentElement.clientWidth"), evaluate_script("document.documentElement.scrollWidth")

    click_on "All notes"
    assert_selector "[role=menuitem]", text: "#ministry"
    all("[role=menuitem]").each do |item|
      assert_operator item.evaluate_script("this.offsetHeight"), :>=, 44, "#{item.text} is too small to tap"
    end
    find("[role=menuitem]", text: "Quick references").click

    assert_selector "main .note-card", count: 1
    assert_selector "main .note-card", text: "Daniel 2 image: quick reference"
    assert_accessible

    click_on "Quick references"
    assert_selector "[role=menuitem][aria-current=true]", text: "Quick references"
    capture_screens("phone-notes-menu", viewports: ScreenshotHelper::VIEWPORTS.slice(:phone))
  end

  test "make a Notes-only collection from the menu" do
    visit notes_url

    click_on "All notes"
    find("[role=menuitem]", text: "New collection").click
    within("dialog[open]", text: "New collection") do
      fill_in "Name", with: "Convention 2027"
      choose "Notes only"
      assert_accessible
      click_on "Create collection"
    end

    assert_button "Convention 2027"
    assert users(:head).collections.find_by!(name: "Convention 2027").used_in_notes?
  end

  test "filter by color" do
    visit notes_url

    within("[role=group][aria-labelledby=note-color-filter-label]") do
      all("button").each do |swatch|
        assert_operator swatch.evaluate_script("this.offsetHeight"), :>=, 44, "#{swatch.text} is too small to tap"
      end
      click_on "Only green notes"
    end

    assert_selector "main .note-card", count: 1
    assert_selector "main .note-card.note-card--green", text: "Questions for my return visit"
    assert_equal "true", find_button("Only green notes")[:"aria-pressed"]
    assert_accessible
  end

  test "open a note, change its color and save" do
    visit notes_url
    click_on "Ideas for family worship"

    all(".note-color-picker__swatch").each do |swatch|
      assert_operator swatch.evaluate_script("this.offsetWidth"), :>=, 44, "a swatch is too small to tap"
      assert_operator swatch.evaluate_script("this.offsetHeight"), :>=, 44, "a swatch is too small to tap"
    end
    assert_operator find("section[aria-labelledby=note-scriptures]").evaluate_script("this.getBoundingClientRect().top"), :>=,
      find("main .note-card").evaluate_script("this.getBoundingClientRect().bottom"), "the side panel isn't under the note"

    find("label[for=personal_note_color_blue]").click
    assert_selector ".note-color-picker__chosen", text: "Blue"
    click_on "Save note"

    assert_text "Note saved."
    assert_selector "main .note-card.note-card--blue", text: "Blue note"
    assert_equal "blue", personal_notes(:head_family_worship).reload.color
    assert_equal evaluate_script("document.documentElement.clientWidth"), evaluate_script("document.documentElement.scrollWidth")
    assert_accessible
    capture_screens("phone-note")

    visit notes_url
    assert_selector "main .note-card.note-card--blue", text: "Ideas for family worship"
    capture_screens("phone-notes")
  end

  private
    def notes_url
      household_personal_notes_url(household_id: households(:home))
    end
end
