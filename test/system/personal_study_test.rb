require "application_system_test_case"

class PersonalStudiesTest < ApplicationSystemTestCase
  END_OF_TEXT = RUBY_PLATFORM.include?("darwin") ? [ :command, :down ] : [ :control, :end ]

  setup { sign_in identities(:head) }

  test "create a study in a new collection, tag it, write notes with a scripture reference, find it by tag" do
    visit household_personal_studies_url(household_id: households(:home))

    assert_selector "h1", text: "Personal study"
    assert_selector "aside nav [aria-current=page]", text: "Personal study"
    assert_accessible
    capture_screens("personal-studies")

    click_on "New collection"
    within("dialog[open]") do
      fill_in "Name", with: "Convention 2027"
      assert_checked_field "Personal study and Notes"
      choose "Personal study only"
      click_on "Create collection"
    end
    assert_selector "nav[aria-label='Collections'] [aria-current=page]", text: "Convention 2027"

    click_on "New study", match: :first
    assert_selector "h1", text: "New study"
    assert_selector "select option[selected]", text: "Convention 2027"
    assert_accessible
    fill_in "Title", with: "Why do we pray?"
    click_on "Start study"

    assert_text "Study started."
    assert_selector "h1", text: "Why do we pray?"
    within("nav[aria-label=Breadcrumb]") { assert_link "Convention 2027" }

    find_field("Add a tag").send_keys("Prayer", :enter)
    within("[id^=tag_editor_personal_study]") { assert_selector "a.Label", text: "#prayer" }

    editor = find("lexxy-editor [contenteditable='true']")
    editor.click
    editor.send_keys(END_OF_TEXT, "Read Philippians 4:6 often")
    click_on "Save notes"

    assert_text "Notes saved."
    assert_selector "lexxy-editor .scripture-link", text: "Philippians 4:6"
    assert_accessible
    capture_screens("personal-study")

    visit household_personal_studies_url(household_id: households(:home))
    within("nav[aria-label='My tags']") { click_on "#prayer" }

    assert_selector "main .Box-row", count: 1
    assert_selector "main .Box-row", text: "Why do we pray?"
    assert_accessible
    capture_screens("personal-studies-tag")
  end

  test "search, then delete a study after the dialog" do
    visit household_personal_studies_url(household_id: households(:home))

    fill_in "Search titles, collections and tags", with: "Daniel\n"
    assert_selector "main .Box-row", count: 1
    click_on "The meaning of Daniel 2"

    assert_turbo_idle
    find("button[aria-label='Study actions']").click
    click_on "Delete study…"
    within("dialog[open]") { click_on "Delete study" }

    assert_text "Study deleted."
    assert_no_text "The meaning of Daniel 2"
  end

  test "on a desktop the study's menu opens on Rename from the keyboard, without the phone's items, and the panels aren't tab stops" do
    visit household_personal_study_url(household_id: households(:home), id: personal_studies(:head_suffering))
    assert_turbo_idle

    assert_selector "[role=tabpanel][tabindex='-1']", count: 3
    assert_no_selector "[role=tablist]"
    find("button[aria-label='Study actions']").send_keys(:enter)
    assert_selector "[role=menuitem]:focus", text: "Rename…"
    assert_no_selector "[role=menuitem]", text: "Tags…"
    assert_no_selector "[role=menuitem]", text: "Plan a family study from this"
    assert_field "Add a tag"
  end

  test "an empty Personal study" do
    sign_in identities(:eli)
    visit household_personal_studies_url(household_id: households(:home))

    assert_text "No studies yet."
    assert_link "New study"
    assert_accessible
    capture_screens("personal-studies-empty")
  end
end
