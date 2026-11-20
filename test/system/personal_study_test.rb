require "application_system_test_case"
require_relative "../support/study_answer_helper"

class PersonalStudiesTest < ApplicationSystemTestCase
  include StudyAnswerHelper

  END_OF_TEXT = RUBY_PLATFORM.include?("darwin") ? [ :command, :down ] : [ :control, :end ]
  PANEL = "section[aria-labelledby=study-note]".freeze

  setup { sign_in identities(:head) }

  test "create a study in a new collection, tag it, find it by tag" do
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
    assert_accessible
    capture_screens("personal-study")

    visit household_personal_studies_url(household_id: households(:home))
    within("nav[aria-label='My tags']") { click_on "#prayer" }

    assert_selector "main .Box-row", count: 1
    assert_selector "main .Box-row", text: "Why do we pray?"
    assert_accessible
    capture_screens("personal-studies-tag")
  end

  # docs/design/personal-study.md, Save to note (frames personal-study-no-note.png, personal-study-note.png).
  test "save two answers to the study's one note, see them in the panel, open it in Notes from your study, then delete the study" do
    study = personal_studies(:head_suffering)
    personal_study_question(study, prompt: "Where did suffering come from?", status: "answered", sources: [ { "url" => "https://www.jw.org/en/bible-teachings/questions/why-does-god-allow-suffering/", "title" => "Why Does God Allow Suffering?" } ],
      answer: { "not_found" => false, "not_found_note" => "", "paragraphs" => [ "Jehovah never causes suffering (James 1:13)." ], "next_questions" => [] })
    personal_study_question(study, prompt: "Will suffering ever end?", status: "answered",
      answer: { "not_found" => false, "not_found_note" => "", "paragraphs" => [ "Yes, God's Kingdom will end it (Revelation 21:4)." ], "next_questions" => [] })
    visit household_personal_study_url(household_id: households(:home), id: study)

    assert_no_button "Save as a note"
    within(question_card("Where did suffering come from?")) { assert_button "Save to note" }
    assert_accessible
    capture_screens("personal-study-no-note")

    within(question_card("Where did suffering come from?")) do
      click_on "Save to note"
      assert_text "Saved to note"
      assert_link "Open note"
      assert_no_button "Save to note"
    end
    within(PANEL) { assert_text "Jehovah never causes suffering" }
    within(question_card("Will suffering ever end?")) do
      click_on "Save to note"
      assert_text "Saved to note"
    end
    assert_no_button "Save as a note"
    assert_accessible
    capture_screens("personal-study-note")

    within(PANEL) do
      assert_text "Jehovah never causes suffering"
      assert_selector ".scripture-link", text: "James 1:13"
      assert_text "Yes, God's Kingdom will end it"
      assert_text "In Notes · Edited"
      click_on "Open in Notes"
    end

    assert_selector "main h1", text: "Why does Jehovah allow suffering?"
    within("main .note-card") do
      assert_text "From your study"
      assert_link "Why does Jehovah allow suffering?", href: household_personal_study_path(household_id: households(:home), id: study)
      assert_selector "h2", text: "Where did suffering come from?"
      assert_selector "h2", text: "Will suffering ever end?"
      assert_link "Why Does God Allow Suffering?"
      assert_selector ".scripture-link", text: "Revelation 21:4"
    end
    assert_equal 1, users(:head).personal_notes.where(personal_study: study).count
    assert_accessible
    capture_screens("note-read-from-study")
    note_url = current_url

    visit household_personal_study_url(household_id: households(:home), id: study)
    assert_turbo_idle
    find("button[aria-label='Study actions']").click
    click_on "Delete study…"
    within("dialog[open]") { click_on "Delete study" }
    assert_text "Study deleted."

    visit note_url
    assert_selector "main h1", text: "Why does Jehovah allow suffering?"
    assert_text "Where did suffering come from?"
    assert_no_text "From your study"
  end

  # docs/design/personal-study.md, The study page: Study note (frames personal-study-no-note.png,
  # personal-study-note-editing.png).
  test "start a note, write in it and save it, then Edit and Cancel change nothing" do
    study = personal_studies(:head_suffering)
    visit household_personal_study_url(household_id: households(:home), id: study)

    within(PANEL) do
      assert_text "No note yet. Save an answer to start one, or write your own."
      click_on "Start a note"
      editable = find("lexxy-editor [contenteditable='true']")
      editable.click
      editable.send_keys("Read Romans 5:12 with the family. ")
      assert_text "Title, color and tags are in Notes."
      find("lexxy-toolbar button[name=scripture]").click
    end
    within("[data-controller='scripture-picker']") do
      find("[role=option]", text: /\APhilippians\b/).click
      within(".scripture-picker__chapters") { click_on "4" }
      within(".scripture-picker__verses") { click_on "6" }
      click_on "Insert"
    end
    within(PANEL) { assert_selector "lexxy-editor .scripture-link", text: "Philippians 4:6" }
    assert_accessible
    capture_screens("personal-study-note-editing")
    within(PANEL) { click_on "Save note" }

    within(PANEL) do
      assert_no_selector "lexxy-editor"
      assert_selector ".scripture-link", text: "Romans 5:12"
      assert_selector ".scripture-link", text: "Philippians 4:6"
      assert_text "with the family"
      click_on "Edit"
      find("lexxy-editor [contenteditable='true']").send_keys(END_OF_TEXT, " and never mind")
      click_on "Cancel"
      assert_no_selector "lexxy-editor"
      assert_text "with the family"
      assert_no_text "never mind"
    end
    assert_equal "Why does Jehovah allow suffering?", study.reload.note.title
    assert_accessible
  end

  test "an answer saved while the editor is open stays in the note, and the editor's save is refused with What you wrote" do
    study = personal_studies(:head_suffering)
    study.with_lock { study.start_note }.update!(body: "<p>My first thought.</p>")
    personal_study_question(study, status: "answered",
      answer: { "not_found" => false, "not_found_note" => "", "paragraphs" => [ "Jehovah never causes suffering (James 1:13)." ], "next_questions" => [] })
    visit household_personal_study_url(household_id: households(:home), id: study)

    within(PANEL) do
      click_on "Edit"
      find("lexxy-editor [contenteditable='true']").send_keys(END_OF_TEXT, " Words typed meanwhile.")
    end
    within(question_card("Why does Jehovah allow suffering?")) do
      click_on "Save to note"
      assert_text "Saved to note"
    end
    within(PANEL) do
      assert_selector "lexxy-editor", text: "Words typed meanwhile."
      click_on "Save note"

      assert_text "This note changed after you started editing, so your changes weren't saved."
      assert_selector "lexxy-editor", text: "Jehovah never causes suffering"
      within("section[aria-labelledby=what-you-wrote]") { assert_text "My first thought. Words typed meanwhile." }
    end
    assert_includes study.note.reload.body.to_plain_text, "Jehovah never causes suffering"
    assert_not_includes study.note.body.to_plain_text, "Words typed meanwhile."
    assert_accessible
    capture_screens("personal-study-note-conflict")
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
